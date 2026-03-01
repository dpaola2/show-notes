require "rails_helper"

RSpec.describe Episode, type: :model do
  describe ".library_ready_since" do
    let(:user) { create(:user) }
    let(:podcast) { create(:podcast, title: "Test Podcast") }

    context "DIG-001: filters by library location" do
      it "includes episodes in the library with ready status" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, :ready, user: user, episode: episode)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).to include(episode)
      end

      it "excludes episodes in the inbox" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, user: user, episode: episode, location: :inbox, processing_status: :ready)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end

      it "excludes episodes in the archive" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, user: user, episode: episode, location: :archive, processing_status: :ready)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end

      it "excludes episodes in the trash" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, user: user, episode: episode, location: :trash, processing_status: :ready)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end
    end

    context "DIG-002: filters by processing_status and updated_at" do
      it "includes library episodes with ready status updated after since" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, :ready, user: user, episode: episode)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).to include(episode)
      end

      it "excludes library episodes with pending status" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        create(:user_episode, :in_library, user: user, episode: episode, processing_status: :pending)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end

      it "excludes library episodes with error status" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        create(:user_episode, :with_error, user: user, episode: episode)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end

      it "excludes library episodes with transcribing status" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        create(:user_episode, :processing, user: user, episode: episode)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end

      it "excludes ready library episodes updated before since" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, :ready, user: user, episode: episode)
        ue.update_column(:updated_at, 3.hours.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end
    end

    context "DIG-002: 24-hour cap calculation" do
      it "includes episodes within 24-hour window when digest_sent_at is stale" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, :ready, user: user, episode: episode)
        ue.update_column(:updated_at, 12.hours.ago)

        since = [ 3.days.ago, 24.hours.ago ].compact.max
        results = Episode.library_ready_since(user, since)
        expect(results).to include(episode)
      end

      it "excludes episodes older than 24 hours when digest_sent_at is nil" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, :ready, user: user, episode: episode)
        ue.update_column(:updated_at, 25.hours.ago)

        since = [ nil, 24.hours.ago ].compact.max
        results = Episode.library_ready_since(user, since)
        expect(results).not_to include(episode)
      end
    end

    context "user scoping" do
      it "does not include episodes from other users" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, :ready, user: other_user, episode: episode)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end
    end

    context "ordering" do
      it "orders by user_episodes.updated_at descending (most recent first)" do
        podcast_a = create(:podcast, title: "AAA Podcast")
        podcast_z = create(:podcast, title: "ZZZ Podcast")

        ep_z = create(:episode, podcast: podcast_z, published_at: 1.day.ago)
        create(:summary, episode: ep_z)
        ep_a_old = create(:episode, podcast: podcast_a, published_at: 2.days.ago)
        create(:summary, episode: ep_a_old)
        ep_a_new = create(:episode, podcast: podcast_a, published_at: 1.day.ago)
        create(:summary, episode: ep_a_new)

        ue_z = create(:user_episode, :ready, user: user, episode: ep_z)
        ue_z.update_column(:updated_at, 3.hours.ago)
        ue_a_old = create(:user_episode, :ready, user: user, episode: ep_a_old)
        ue_a_old.update_column(:updated_at, 1.hour.ago)
        ue_a_new = create(:user_episode, :ready, user: user, episode: ep_a_new)
        ue_a_new.update_column(:updated_at, 2.hours.ago)

        results = Episode.library_ready_since(user, 4.hours.ago)
        expect(results.to_a).to eq([ ep_a_old, ep_a_new, ep_z ])
      end
    end

    context "eager loading" do
      it "preloads summary association" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        ue = create(:user_episode, :ready, user: user, episode: episode)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results.first.association(:summary)).to be_loaded
      end
    end
  end
end
