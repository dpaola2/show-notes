class CleanupTrashJob < ApplicationJob
  queue_as :default

  RETENTION_PERIOD = 90.days

  def perform
    # Delete episodes trashed more than 90 days ago (not including exactly 90 days)
    cutoff = RETENTION_PERIOD.ago
    old_trashed_episodes = UserEpisode
      .in_trash
      .where("trashed_at < ?", cutoff)

    count = old_trashed_episodes.count
    old_trashed_episodes.destroy_all

    Rails.logger.info("[CleanupTrashJob] Deleted #{count} episodes trashed more than #{RETENTION_PERIOD.inspect} ago")
  end
end
