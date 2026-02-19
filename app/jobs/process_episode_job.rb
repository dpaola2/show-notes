class ProcessEpisodeJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(user_episode_id) { "transcription" }, to: 3

  MAX_RETRIES = 5
  BASE_DELAY = 60 # 1 minute base delay

  def perform(user_episode_id)
    user_episode = UserEpisode.find(user_episode_id)
    episode = user_episode.episode

    # Reset retry tracking on fresh attempt
    user_episode.update!(next_retry_at: nil) if user_episode.retry_count.zero?

    # Check if another user already processed this episode
    if episode.transcript.present? && episode.summary.present?
      user_episode.update!(processing_status: :ready, retry_count: 0, next_retry_at: nil)
      GenerateOgImageJob.perform_later(episode.id) unless episode.og_image.attached?
      return
    end

    # Step 1: Transcribe with AssemblyAI (if not already done)
    # AssemblyAI fetches the audio directly from the URL - no download needed
    unless episode.transcript.present?
      user_episode.update!(processing_status: :transcribing)
      transcript = AssemblyAiClient.transcribe(episode.audio_url)
      episode.create_transcript!(content: transcript.to_json)
    end

    # Step 2: Summarize with Claude (if not already done)
    unless episode.summary.present?
      user_episode.update!(processing_status: :summarizing)
      summary = ClaudeClient.summarize_chunked(episode.transcript.content)
      episode.create_summary!(
        sections: summary["sections"],
        quotes: summary["quotes"]
      )

      # Step 3: Enqueue OG image generation
      GenerateOgImageJob.perform_later(episode.id)
    end

    user_episode.update!(processing_status: :ready, retry_count: 0, next_retry_at: nil)

  rescue ClaudeClient::RateLimitError, AssemblyAiClient::Error => e
    handle_retryable_error(user_episode, e)
  rescue => e
    user_episode.update!(
      processing_status: :error,
      processing_error: e.message,
      last_error_at: Time.current
    )
  end

  private

  def handle_retryable_error(user_episode, error)
    new_retry_count = user_episode.retry_count + 1

    if new_retry_count > MAX_RETRIES
      user_episode.update!(
        processing_status: :error,
        processing_error: "#{error.message} (exceeded #{MAX_RETRIES} retries)",
        last_error_at: Time.current
      )
      return
    end

    # Exponential backoff: 1min, 2min, 4min, 8min, 16min
    delay_seconds = BASE_DELAY * (2 ** (new_retry_count - 1))
    next_retry = delay_seconds.seconds.from_now

    user_episode.update!(
      retry_count: new_retry_count,
      next_retry_at: next_retry,
      last_error_at: Time.current,
      processing_error: "#{error.message} — retry #{new_retry_count}/#{MAX_RETRIES} at #{next_retry.strftime('%H:%M:%S')}"
    )

    # Schedule the retry
    ProcessEpisodeJob.set(wait: delay_seconds.seconds).perform_later(user_episode.id)
  end
end
