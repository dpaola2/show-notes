class OpmlImportService
  Result = Struct.new(:subscribed, :skipped, :failed, keyword_init: true)

  def self.subscribe_all(user, feeds)
    new(user, feeds).subscribe_all
  end

  def self.process_favorites(user, podcast_ids)
    new(user, []).process_favorites(podcast_ids)
  end

  def initialize(user, feeds)
    @user = user
    @feeds = feeds
  end

  def subscribe_all
    subscribed = []
    skipped = []
    failed = []

    @feeds.each do |feed|
      podcast = Podcast.find_or_create_by!(feed_url: feed.feed_url) do |p|
        p.guid = feed.feed_url
        p.title = feed.title || "Unknown Podcast"
      end

      subscription = @user.subscriptions.find_or_initialize_by(podcast: podcast)
      if subscription.new_record?
        subscription.save!
        subscribed << podcast
      else
        skipped << podcast
      end
    rescue => e
      failed << { feed: feed, error: e.message }
    end

    Result.new(subscribed: subscribed, skipped: skipped, failed: failed)
  end

  def process_favorites(podcast_ids)
    podcasts = @user.podcasts.where(id: podcast_ids)

    podcasts.each do |podcast|
      episodes = PodcastFeedParser.parse(podcast.feed_url)
      latest = episodes.first
      next unless latest

      episode = podcast.episodes.find_or_initialize_by(guid: latest.guid) do |ep|
        ep.title = latest.title
        ep.description = latest.description
        ep.audio_url = latest.audio_url
        ep.duration_seconds = latest.duration_seconds
        ep.published_at = latest.published_at
      end
      episode.save! if episode.new_record?

      user_episode = @user.user_episodes.find_or_initialize_by(episode: episode)
      if user_episode.new_record?
        user_episode.location = :library
        user_episode.processing_status = :pending
        user_episode.save!
        ProcessEpisodeJob.perform_later(user_episode.id)
      elsif !user_episode.ready?
        ProcessEpisodeJob.perform_later(user_episode.id)
      end
    rescue PodcastFeedParser::Error => e
      Rails.logger.warn("[OpmlImportService] Failed to fetch feed for #{podcast.title}: #{e.message}")
    end
  end
end
