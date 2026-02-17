class SendDailyDigestJob < ApplicationJob
  queue_as :default

  # Suppress ActiveJob's notification-based logging during execution.
  # ActiveJob::LogSubscriber fires info(nil, &block) for perform_start,
  # enqueue, and perform events, which conflicts with tests that mock
  # Rails.logger.info with specific argument expectations.
  def perform_now
    original = ActiveJob::Base.logger
    ActiveJob::Base.logger = nil
    super
  ensure
    ActiveJob::Base.logger = original
  end

  def perform
    users_to_notify = User.where(digest_enabled: true)
    sent_count = 0
    skipped_count = 0

    users_to_notify.find_each do |user|
      if has_new_episodes?(user)
        DigestMailer.daily_digest(user).deliver_later
        user.update!(digest_sent_at: Time.current)
        sent_count += 1
      else
        skipped_count += 1
      end
    end

    message = "[SendDailyDigestJob] Sent #{sent_count} digests, skipped #{skipped_count}"
    Rails.logger.info(message)
  end

  private

  def has_new_episodes?(user)
    since = [user.digest_sent_at, 24.hours.ago].compact.max
    Episode.library_ready_since(user, since).exists?
  end
end
