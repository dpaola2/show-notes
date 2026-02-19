require "rails_helper"

RSpec.describe Episode, type: :model do
  describe ".library_ready_since — featured digest scope changes" do
    let(:user) { create(:user) }
    let(:podcast) { create(:podcast) }

    context "FE-006 / RE-005: excludes episodes without completed summaries" do
      it "excludes episodes that have no summary record" do
        episode = create(:episode, podcast: podcast)
        ue = create(:user_episode, :ready, user: user, episode: episode)
        ue.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).not_to include(episode)
      end

      it "returns no episodes when all qualifying episodes lack summaries" do
        3.times do
          ep = create(:episode, podcast: podcast)
          ue = create(:user_episode, :ready, user: user, episode: ep)
          ue.update_column(:updated_at, 1.hour.ago)
        end

        results = Episode.library_ready_since(user, 2.hours.ago)
        expect(results).to be_empty
      end
    end

    context "FE-001 / RE-002: orders by user_episodes.updated_at DESC" do
      it "returns episodes ordered by recency across different podcasts" do
        podcast_a = create(:podcast, title: "AAA Podcast")
        podcast_z = create(:podcast, title: "ZZZ Podcast")

        ep_old = create(:episode, podcast: podcast_a, title: "Old Episode")
        create(:summary, episode: ep_old)
        ue_old = create(:user_episode, :ready, user: user, episode: ep_old)
        ue_old.update_column(:updated_at, 3.hours.ago)

        ep_newest = create(:episode, podcast: podcast_z, title: "Newest Episode")
        create(:summary, episode: ep_newest)
        ue_newest = create(:user_episode, :ready, user: user, episode: ep_newest)
        ue_newest.update_column(:updated_at, 30.minutes.ago)

        ep_mid = create(:episode, podcast: podcast_a, title: "Mid Episode")
        create(:summary, episode: ep_mid)
        ue_mid = create(:user_episode, :ready, user: user, episode: ep_mid)
        ue_mid.update_column(:updated_at, 1.hour.ago)

        results = Episode.library_ready_since(user, 4.hours.ago)
        expect(results.to_a).to eq([ ep_newest, ep_mid, ep_old ])
      end
    end
  end
end
