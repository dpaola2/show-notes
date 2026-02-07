require "rails_helper"

RSpec.describe OpmlImportService do
  let!(:user) { create(:user) }

  describe ".subscribe_all" do
    let(:feeds) do
      [
        OpmlParser::Feed.new(title: "Podcast One", feed_url: "https://feeds.example.com/one"),
        OpmlParser::Feed.new(title: "Podcast Two", feed_url: "https://feeds.example.com/two"),
        OpmlParser::Feed.new(title: "Podcast Three", feed_url: "https://feeds.example.com/three")
      ]
    end

    context "SUB-001: creating podcasts and subscriptions for all feeds" do
      it "creates Podcast records for each feed" do
        expect {
          described_class.subscribe_all(user, feeds)
        }.to change(Podcast, :count).by(3)
      end

      it "creates Subscription records for each feed" do
        expect {
          described_class.subscribe_all(user, feeds)
        }.to change(Subscription, :count).by(3)
      end

      it "sets feed_url as guid for OPML-imported podcasts" do
        described_class.subscribe_all(user, feeds)

        podcast = Podcast.find_by(feed_url: "https://feeds.example.com/one")
        expect(podcast.guid).to eq("https://feeds.example.com/one")
      end

      it "sets the podcast title from the feed" do
        described_class.subscribe_all(user, feeds)

        podcast = Podcast.find_by(feed_url: "https://feeds.example.com/one")
        expect(podcast.title).to eq("Podcast One")
      end

      it "returns a Result with subscribed podcasts" do
        result = described_class.subscribe_all(user, feeds)

        expect(result).to be_a(OpmlImportService::Result)
        expect(result.subscribed.length).to eq(3)
        expect(result.skipped).to be_empty
        expect(result.failed).to be_empty
      end
    end

    context "SUB-003: skipping duplicate feeds (already subscribed)" do
      let!(:existing_podcast) { create(:podcast, feed_url: "https://feeds.example.com/one", guid: "12345") }

      before do
        create(:subscription, user: user, podcast: existing_podcast)
      end

      it "does not create a duplicate Podcast record" do
        expect {
          described_class.subscribe_all(user, feeds)
        }.to change(Podcast, :count).by(2) # only 2 new, not 3
      end

      it "does not create a duplicate Subscription record" do
        expect {
          described_class.subscribe_all(user, feeds)
        }.to change(Subscription, :count).by(2)
      end

      it "reports the existing podcast as skipped" do
        result = described_class.subscribe_all(user, feeds)

        expect(result.skipped.length).to eq(1)
        expect(result.skipped.first).to eq(existing_podcast)
      end

      it "preserves the existing podcast's original guid" do
        described_class.subscribe_all(user, feeds)

        existing_podcast.reload
        expect(existing_podcast.guid).to eq("12345")
      end
    end

    context "SUB-004: continuing past feeds that fail" do
      let(:feeds_with_bad_url) do
        [
          OpmlParser::Feed.new(title: "Good Podcast", feed_url: "https://feeds.example.com/good"),
          OpmlParser::Feed.new(title: nil, feed_url: nil), # will fail validation
          OpmlParser::Feed.new(title: "Another Good", feed_url: "https://feeds.example.com/another")
        ]
      end

      it "continues processing after a failure" do
        result = described_class.subscribe_all(user, feeds_with_bad_url)

        expect(result.subscribed.length).to eq(2)
        expect(result.failed.length).to eq(1)
      end

      it "reports the failed feed with error details" do
        result = described_class.subscribe_all(user, feeds_with_bad_url)

        failure = result.failed.first
        expect(failure[:feed].title).to be_nil
        expect(failure[:error]).to be_present
      end
    end

    context "PRC-005/SUB-002: subscribe_all does not enqueue any jobs" do
      it "does not enqueue ProcessEpisodeJob" do
        expect {
          described_class.subscribe_all(user, feeds)
        }.not_to have_enqueued_job(ProcessEpisodeJob)
      end

      it "does not enqueue FetchPodcastFeedJob" do
        expect {
          described_class.subscribe_all(user, feeds)
        }.not_to have_enqueued_job(FetchPodcastFeedJob)
      end
    end
  end

  describe ".process_favorites" do
    let!(:podcast1) { create(:podcast, feed_url: "https://feeds.example.com/one") }
    let!(:podcast2) { create(:podcast, feed_url: "https://feeds.example.com/two") }
    let!(:unselected_podcast) { create(:podcast, feed_url: "https://feeds.example.com/three") }

    let(:episode1_struct) do
      PodcastFeedParser::Episode.new(
        guid: "ep1-guid",
        title: "Latest Episode 1",
        description: "Description 1",
        audio_url: "https://example.com/ep1.mp3",
        duration_seconds: 3600,
        published_at: 1.day.ago
      )
    end

    let(:episode2_struct) do
      PodcastFeedParser::Episode.new(
        guid: "ep2-guid",
        title: "Latest Episode 2",
        description: "Description 2",
        audio_url: "https://example.com/ep2.mp3",
        duration_seconds: 2400,
        published_at: 2.days.ago
      )
    end

    before do
      create(:subscription, user: user, podcast: podcast1)
      create(:subscription, user: user, podcast: podcast2)
      create(:subscription, user: user, podcast: unselected_podcast)

      # Mock RSS feed parsing for selected podcasts
      allow(PodcastFeedParser).to receive(:parse)
        .with(podcast1.feed_url)
        .and_return([episode1_struct])

      allow(PodcastFeedParser).to receive(:parse)
        .with(podcast2.feed_url)
        .and_return([episode2_struct])
    end

    context "PRC-001: fetching and processing latest episode from each favorite" do
      it "creates Episode records for each selected podcast" do
        expect {
          described_class.process_favorites(user, [podcast1.id, podcast2.id])
        }.to change(Episode, :count).by(2)
      end

      it "creates UserEpisode records for each selected podcast" do
        expect {
          described_class.process_favorites(user, [podcast1.id, podcast2.id])
        }.to change(UserEpisode, :count).by(2)
      end

      it "creates UserEpisode in library location (not inbox)" do
        described_class.process_favorites(user, [podcast1.id])

        user_episode = UserEpisode.last
        expect(user_episode.location).to eq("library")
      end

      it "sets processing_status to pending" do
        described_class.process_favorites(user, [podcast1.id])

        user_episode = UserEpisode.last
        expect(user_episode.processing_status).to eq("pending")
      end
    end

    context "PRC-003: background processing via ProcessEpisodeJob" do
      it "enqueues ProcessEpisodeJob for each selected podcast" do
        expect {
          described_class.process_favorites(user, [podcast1.id, podcast2.id])
        }.to have_enqueued_job(ProcessEpisodeJob).twice
      end

      it "passes the user_episode id to the job" do
        described_class.process_favorites(user, [podcast1.id])

        user_episode = UserEpisode.last
        expect(ProcessEpisodeJob).to have_been_enqueued.with(user_episode.id)
      end
    end

    context "PRC-005: non-selected podcasts are not processed" do
      it "does not fetch the feed for unselected podcasts" do
        expect(PodcastFeedParser).not_to receive(:parse).with(unselected_podcast.feed_url)

        described_class.process_favorites(user, [podcast1.id])
      end
    end

    context "when the podcast is not subscribed by the user" do
      let!(:other_user_podcast) { create(:podcast, feed_url: "https://feeds.example.com/other") }

      it "ignores podcast IDs not belonging to the user" do
        expect {
          described_class.process_favorites(user, [other_user_podcast.id])
        }.not_to change(Episode, :count)
      end
    end

    context "when PodcastFeedParser raises an error" do
      before do
        allow(PodcastFeedParser).to receive(:parse)
          .with(podcast1.feed_url)
          .and_raise(PodcastFeedParser::FetchError, "HTTP 500")
      end

      it "continues processing remaining podcasts" do
        expect {
          described_class.process_favorites(user, [podcast1.id, podcast2.id])
        }.to change(Episode, :count).by(1) # only podcast2 succeeds
      end

      it "logs a warning for the failed feed" do
        expect(Rails.logger).to receive(:warn).with(/Failed to fetch feed/)

        described_class.process_favorites(user, [podcast1.id, podcast2.id])
      end
    end

    context "when the episode already exists" do
      let!(:existing_episode) do
        create(:episode, podcast: podcast1, guid: "ep1-guid", title: "Already There",
          audio_url: "https://example.com/ep1.mp3")
      end

      it "does not create a duplicate episode" do
        expect {
          described_class.process_favorites(user, [podcast1.id])
        }.not_to change(Episode, :count)
      end

      it "still creates a UserEpisode and enqueues processing" do
        expect {
          described_class.process_favorites(user, [podcast1.id])
        }.to change(UserEpisode, :count).by(1)
          .and have_enqueued_job(ProcessEpisodeJob)
      end
    end

    context "when the UserEpisode already exists in library and is ready" do
      let!(:existing_episode) do
        create(:episode, podcast: podcast1, guid: "ep1-guid", title: "Already There",
          audio_url: "https://example.com/ep1.mp3")
      end
      let!(:existing_ue) do
        create(:user_episode, :ready, user: user, episode: existing_episode)
      end

      it "does not enqueue ProcessEpisodeJob again" do
        expect {
          described_class.process_favorites(user, [podcast1.id])
        }.not_to have_enqueued_job(ProcessEpisodeJob)
      end
    end
  end
end
