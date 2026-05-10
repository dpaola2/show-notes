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
      relation = Episode.eligible_for_drip(user)
      if relation.exists?
        episodes = relation.limit(6).to_a
        DigestMailer
          .daily_digest(
            user,
            featured_episode_id: episodes.first&.id,
            recent_episode_ids: episodes.drop(1).map(&:id)
          )
          .deliver_later
        user.update!(digest_sent_at: Time.current)
        sent_count += 1
      else
        skipped_count += 1
      end
    end

    message = "[SendDailyDigestJob] Sent #{sent_count} digests, skipped #{skipped_count}"
    Rails.logger.info(message)
  end
end
