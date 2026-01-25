class RefreshAllFeedsJob < ApplicationJob
  queue_as :default

  def perform
    # Get all podcasts that have at least one subscriber
    podcasts_with_subscribers = Podcast.joins(:subscriptions).distinct

    podcasts_with_subscribers.find_each do |podcast|
      FetchPodcastFeedJob.perform_later(podcast.id)
    end

    Rails.logger.info("[RefreshAllFeedsJob] Enqueued feed refresh for #{podcasts_with_subscribers.count} podcasts")
  end
end
