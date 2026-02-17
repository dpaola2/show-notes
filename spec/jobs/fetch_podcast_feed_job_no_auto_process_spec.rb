require "rails_helper"

RSpec.describe FetchPodcastFeedJob, type: :job do
  include ActiveJob::TestHelper

  let(:podcast) { create(:podcast, feed_url: "https://feeds.example.com/test") }
  let(:user) { create(:user) }
  let!(:subscription) { create(:subscription, user: user, podcast: podcast) }

  let(:episode_data) do
    double(
      guid: "new-library-episode",
      title: "New Episode",
      description: "A new episode",
      audio_url: "https://example.com/new.mp3",
      duration_seconds: 3600,
      published_at: 1.hour.ago
    )
  end

  before do
    allow(PodcastFeedParser).to receive(:parse).and_return([episode_data])
  end

  describe "#perform — no auto-processing" do
    context "TRX-001: does not enqueue transcription on feed fetch" do
      it "does not enqueue AutoProcessEpisodeJob for new episodes" do
        expect {
          described_class.perform_now(podcast.id)
        }.not_to have_enqueued_job(AutoProcessEpisodeJob)
      end
    end
  end
end
