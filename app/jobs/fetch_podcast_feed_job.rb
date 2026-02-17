class FetchPodcastFeedJob < ApplicationJob
  queue_as :default

  def perform(podcast_id, initial_fetch: false)
    podcast = Podcast.find(podcast_id)
    feed = PodcastFeedParser.parse(podcast.feed_url)
    subscribers = podcast.subscriptions.includes(:user)

    episodes_to_process = feed
    # On initial subscribe, only add last 10 episodes
    episodes_to_process = feed.first(10) if initial_fetch

    episodes_to_process.each do |episode_data|
      episode = podcast.episodes.find_or_initialize_by(guid: episode_data.guid)

      if episode.new_record?
        episode.assign_attributes(
          title: episode_data.title,
          description: episode_data.description,
          audio_url: episode_data.audio_url,
          duration_seconds: episode_data.duration_seconds,
          published_at: episode_data.published_at
        )
        episode.save!

        # Create inbox entry for each subscriber
        subscribers.each do |subscription|
          subscription.user.user_episodes.create!(
            episode: episode,
            location: :inbox
          )
        end

      end
    end

    podcast.update!(last_fetched_at: Time.current)
  end
end
