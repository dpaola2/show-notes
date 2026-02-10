class DetectStuckProcessingJob < ApplicationJob
  queue_as :default

  STUCK_THRESHOLD = 30.minutes + 1.second

  def perform
    # Detect stuck UserEpisodes
    UserEpisode
      .where(processing_status: [:transcribing, :summarizing])
      .where("updated_at < ?", STUCK_THRESHOLD.ago)
      .find_each do |ue|
        ue.update!(
          processing_status: :error,
          processing_error: "Processing timed out after #{STUCK_THRESHOLD.inspect}",
          last_error_at: Time.current
        )
      end

    # Detect stuck Episodes
    Episode
      .where(processing_status: [:transcribing, :summarizing])
      .where("updated_at < ?", STUCK_THRESHOLD.ago)
      .find_each do |ep|
        ep.update!(
          processing_status: :error,
          processing_error: "Processing timed out after #{STUCK_THRESHOLD.inspect}",
          last_error_at: Time.current
        )
      end
  end
end
