class AutoProcessEpisodeJob < ApplicationJob
  queue_as :default
  limits_concurrency key: ->(episode_id, **) { "transcription" }, to: 3

  MAX_RETRIES = 5
  BASE_DELAY = 60

  def perform(episode_id, retry_count: 0)
    episode = Episode.find(episode_id)

    # Skip if already processed
    return if episode.transcript.present? && episode.summary.present?

    # Step 1: Transcribe
    unless episode.transcript.present?
      episode.update!(processing_status: :transcribing)
      transcript = AssemblyAiClient.transcribe(episode.audio_url)
      episode.create_transcript!(content: transcript.to_json)
    end

    # Step 2: Summarize
    unless episode.summary.present?
      episode.update!(processing_status: :summarizing)
      summary = ClaudeClient.summarize_chunked(episode.transcript.content)
      episode.create_summary!(
        sections: summary["sections"],
        quotes: summary["quotes"]
      )
    end

    episode.update!(processing_status: :ready)

  rescue ClaudeClient::RateLimitError, AssemblyAiClient::Error => e
    handle_retryable_error(episode, episode_id, retry_count, e)
  rescue => e
    episode&.update!(
      processing_status: :error,
      processing_error: e.message,
      last_error_at: Time.current
    )
    Rails.logger.error("[AutoProcessEpisodeJob] Episode #{episode_id} failed: #{e.message}")
  end

  private

  def handle_retryable_error(episode, episode_id, retry_count, error)
    new_retry_count = retry_count + 1
    if new_retry_count > MAX_RETRIES
      episode.update!(
        processing_status: :error,
        processing_error: "#{error.message} (exceeded #{MAX_RETRIES} retries)",
        last_error_at: Time.current
      )
      Rails.logger.error("[AutoProcessEpisodeJob] Episode #{episode_id} exceeded #{MAX_RETRIES} retries: #{error.message}")
      return
    end

    delay_seconds = BASE_DELAY * (2 ** (new_retry_count - 1))
    episode.update!(
      processing_error: "Retrying #{new_retry_count}/#{MAX_RETRIES}",
      last_error_at: Time.current
    )
    AutoProcessEpisodeJob.set(wait: delay_seconds.seconds).perform_later(episode_id, retry_count: new_retry_count)
  end
end
