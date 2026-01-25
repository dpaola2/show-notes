class ProcessEpisodeJob < ApplicationJob
  queue_as :default

  def perform(user_episode_id)
    user_episode = UserEpisode.find(user_episode_id)
    episode = user_episode.episode

    # Check if another user already processed this episode
    if episode.transcript.present? && episode.summary.present?
      user_episode.update!(processing_status: :ready)
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
      summary = ClaudeClient.summarize(episode.transcript.content)
      episode.create_summary!(
        sections: summary["sections"],
        quotes: summary["quotes"]
      )
    end

    user_episode.update!(processing_status: :ready)

  rescue => e
    user_episode.update!(
      processing_status: :error,
      processing_error: e.message
    )
  end
end
