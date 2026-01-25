class SendDailyDigestJob < ApplicationJob
  queue_as :default

  def perform
    users_to_notify = User.where(digest_enabled: true)
    sent_count = 0
    skipped_count = 0

    users_to_notify.find_each do |user|
      if should_send_digest?(user)
        DigestMailer.daily_digest(user).deliver_later
        user.update!(digest_sent_at: Time.current)
        sent_count += 1
      else
        skipped_count += 1
      end
    end

    Rails.logger.info("[SendDailyDigestJob] Sent #{sent_count} digests, skipped #{skipped_count} (no content)")
  end

  private

  def should_send_digest?(user)
    has_inbox_episodes?(user) || has_recent_library_episodes?(user)
  end

  def has_inbox_episodes?(user)
    user.user_episodes.in_inbox.exists?
  end

  def has_recent_library_episodes?(user)
    user.user_episodes
      .in_library
      .ready
      .where("user_episodes.updated_at > ?", 2.days.ago)
      .exists?
  end
end
