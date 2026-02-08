namespace :onboarding do
  desc "Backfill: auto-process ~10 most recent unprocessed episodes per podcast for all subscribers"
  task backfill_episodes: :environment do
    User.find_each do |user|
      user.podcasts.each do |podcast|
        episodes = podcast.episodes
          .left_joins(:summary)
          .where(summaries: { id: nil })
          .order(published_at: :desc)
          .limit(10)

        episodes.each do |episode|
          next if episode.transcript.present? && episode.summary.present?
          AutoProcessEpisodeJob.perform_later(episode.id)
        end

        puts "  Queued #{episodes.size} episodes for #{podcast.title}"
      end
    end
  end
end
