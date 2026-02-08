require "rails_helper"

RSpec.describe FetchPodcastFeedJob, type: :job do
  include ActiveJob::TestHelper

  let(:podcast) { create(:podcast, feed_url: "https://feeds.example.com/test") }
  let(:user) { create(:user) }
  let!(:subscription) { create(:subscription, user: user, podcast: podcast) }

  let(:episode_data) do
    double(
      guid: "new-episode-guid",
      title: "New Episode",
      description: "A new episode description",
      audio_url: "https://example.com/new-episode.mp3",
      duration_seconds: 3600,
      published_at: 1.hour.ago
    )
  end

  before do
    allow(PodcastFeedParser).to receive(:parse).and_return([ episode_data ])
  end

  describe "#perform" do
    context "AUTO-001: auto-processing triggered on new episode creation" do
      it "enqueues AutoProcessEpisodeJob for new episodes" do
        expect {
          described_class.perform_now(podcast.id)
        }.to have_enqueued_job(AutoProcessEpisodeJob)
      end

      it "creates the new episode in the database" do
        described_class.perform_now(podcast.id)

        episode = podcast.episodes.find_by(guid: "new-episode-guid")
        expect(episode).to be_present
        expect(episode.title).to eq("New Episode")
      end
    end

    context "AUTO-001: does not auto-process existing episodes" do
      before do
        create(:episode, podcast: podcast, guid: "new-episode-guid")
      end

      it "does not enqueue AutoProcessEpisodeJob for existing episodes" do
        expect {
          described_class.perform_now(podcast.id)
        }.not_to have_enqueued_job(AutoProcessEpisodeJob)
      end
    end

    context "AUTO-007: initial_fetch limits to 10 episodes" do
      let(:many_episodes) do
        15.times.map do |i|
          double(
            guid: "episode-#{i}",
            title: "Episode #{i}",
            description: "Description #{i}",
            audio_url: "https://example.com/ep#{i}.mp3",
            duration_seconds: 3600,
            published_at: i.hours.ago
          )
        end
      end

      before do
        allow(PodcastFeedParser).to receive(:parse).and_return(many_episodes)
      end

      it "limits to 10 episodes on initial fetch" do
        described_class.perform_now(podcast.id, initial_fetch: true)

        expect(podcast.episodes.count).to eq(10)
      end

      it "enqueues AutoProcessEpisodeJob for each of the 10 episodes" do
        expect {
          described_class.perform_now(podcast.id, initial_fetch: true)
        }.to have_enqueued_job(AutoProcessEpisodeJob).exactly(10).times
      end
    end
  end
end
