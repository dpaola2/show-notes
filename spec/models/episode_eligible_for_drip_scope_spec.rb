require "rails_helper"

# Specs for SN-17 / M2 — Episode.eligible_for_drip(user) scope.
# Replaces the deleted Episode.library_ready_since(user, since) scope.
#
# Covers:
#   SEL-001: returns the entire ready+library set regardless of when ready
#   SEL-002: requires user_id + library + ready + digest_featured_at IS NULL + Summary
#   SEL-003: ordering is published_at DESC NULLS LAST, episodes.id DESC
#   SEL-006: Episode.library_ready_since is deleted entirely
#   VAL-001: a featured episode never reappears in the scope for that user
#   Cross-user safety: never returns another user's episodes
RSpec.describe Episode, ".eligible_for_drip", type: :model do
  let(:user) { create(:user) }
  let(:podcast) { create(:podcast) }

  describe "SEL-006: legacy scope deletion" do
    it "Episode.library_ready_since no longer exists" do
      expect(Episode.respond_to?(:library_ready_since)).to be(false)
    end
  end

  describe "SEL-001 / SEL-002: eligibility predicate" do
    it "includes a library + ready episode whose UserEpisode has nil digest_featured_at and a Summary" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      ue = create(:user_episode, :ready, user: user, episode: episode)
      ue.update_columns(digest_featured_at: nil)

      expect(Episode.eligible_for_drip(user)).to include(episode)
    end

    it "includes episodes regardless of when their UserEpisode became ready (no 24h window)" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      ue = create(:user_episode, :ready, user: user, episode: episode)
      ue.update_columns(digest_featured_at: nil, updated_at: 90.days.ago)

      expect(Episode.eligible_for_drip(user)).to include(episode)
    end

    it "excludes a UserEpisode that has been featured already (digest_featured_at IS NOT NULL)" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      ue = create(:user_episode, :ready, user: user, episode: episode)
      ue.update_columns(digest_featured_at: 1.day.ago)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "excludes UserEpisodes in inbox" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      create(:user_episode, user: user, episode: episode, location: :inbox, processing_status: :ready)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "excludes UserEpisodes in archive" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      create(:user_episode, user: user, episode: episode, location: :archive, processing_status: :ready)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "excludes UserEpisodes in trash" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      create(:user_episode, user: user, episode: episode,
                            location: :trash, processing_status: :ready, trashed_at: 1.day.ago)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "excludes library UserEpisodes whose processing_status is not ready (pending)" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      create(:user_episode, :in_library, user: user, episode: episode, processing_status: :pending)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "excludes library UserEpisodes whose processing_status is transcribing" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      create(:user_episode, :processing, user: user, episode: episode)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "excludes library UserEpisodes whose processing_status is error" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      create(:user_episode, :with_error, user: user, episode: episode)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "excludes episodes that have no Summary record" do
      episode = create(:episode, podcast: podcast)
      ue = create(:user_episode, :ready, user: user, episode: episode)
      ue.update_columns(digest_featured_at: nil)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end

    it "returns no rows when nothing matches" do
      expect(Episode.eligible_for_drip(user)).to be_empty
    end

    it "returns distinct episodes (no duplicates from JOIN)" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      ue = create(:user_episode, :ready, user: user, episode: episode)
      ue.update_columns(digest_featured_at: nil)

      result = Episode.eligible_for_drip(user).to_a
      expect(result.count(episode)).to eq(1)
    end
  end

  describe "SEL-003: ordering by published_at DESC NULLS LAST, id DESC" do
    it "returns newer published_at episodes before older ones" do
      ep_old = create(:episode, podcast: podcast, published_at: 30.days.ago)
      create(:summary, episode: ep_old)
      ue_old = create(:user_episode, :ready, user: user, episode: ep_old)
      ue_old.update_columns(digest_featured_at: nil)

      ep_new = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep_new)
      ue_new = create(:user_episode, :ready, user: user, episode: ep_new)
      ue_new.update_columns(digest_featured_at: nil)

      expect(Episode.eligible_for_drip(user).to_a).to eq([ ep_new, ep_old ])
    end

    it "tiebreaks identical published_at by episode id DESC" do
      shared_published_at = 5.days.ago.change(usec: 0)

      ep_low = create(:episode, podcast: podcast, published_at: shared_published_at)
      create(:summary, episode: ep_low)
      ue_low = create(:user_episode, :ready, user: user, episode: ep_low)
      ue_low.update_columns(digest_featured_at: nil)

      ep_high = create(:episode, podcast: podcast, published_at: shared_published_at)
      create(:summary, episode: ep_high)
      ue_high = create(:user_episode, :ready, user: user, episode: ep_high)
      ue_high.update_columns(digest_featured_at: nil)

      result = Episode.eligible_for_drip(user).to_a
      low_index  = result.index(ep_low)
      high_index = result.index(ep_high)

      expect(high_index).to be < low_index
    end

    it "places episodes with NULL published_at after episodes with non-NULL published_at (NULLS LAST)" do
      ep_with_date = create(:episode, podcast: podcast, published_at: 7.days.ago)
      create(:summary, episode: ep_with_date)
      ue_with = create(:user_episode, :ready, user: user, episode: ep_with_date)
      ue_with.update_columns(digest_featured_at: nil)

      ep_no_date = create(:episode, podcast: podcast, published_at: nil)
      create(:summary, episode: ep_no_date)
      ue_no_date = create(:user_episode, :ready, user: user, episode: ep_no_date)
      ue_no_date.update_columns(digest_featured_at: nil)

      result = Episode.eligible_for_drip(user).to_a
      expect(result.last).to eq(ep_no_date)
      expect(result.index(ep_with_date)).to be < result.index(ep_no_date)
    end
  end

  describe "VAL-001: featured episodes do not reappear" do
    it "an episode marked as featured for this user is excluded from subsequent results" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      ue = create(:user_episode, :ready, user: user, episode: episode)
      ue.update_columns(digest_featured_at: nil)

      expect(Episode.eligible_for_drip(user)).to include(episode)

      ue.update_columns(digest_featured_at: Time.current)

      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end
  end

  describe "cross-user safety" do
    it "returns zero rows for user_a when only user_b has matching UserEpisodes" do
      user_a = create(:user)
      user_b = create(:user)

      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      ue = create(:user_episode, :ready, user: user_b, episode: episode)
      ue.update_columns(digest_featured_at: nil)

      expect(Episode.eligible_for_drip(user_a)).to be_empty
      expect(Episode.eligible_for_drip(user_b)).to include(episode)
    end

    it "does not return episodes featured for another user but unfeatured for this user" do
      user_a = create(:user)
      user_b = create(:user)

      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)

      # B has it featured already
      ue_b = create(:user_episode, :ready, user: user_b, episode: episode)
      ue_b.update_columns(digest_featured_at: 1.day.ago)

      # A has no UserEpisode at all
      expect(Episode.eligible_for_drip(user_a)).not_to include(episode)
    end
  end

  describe "eager loading" do
    it "preloads :podcast and :summary on returned episodes" do
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)
      ue = create(:user_episode, :ready, user: user, episode: episode)
      ue.update_columns(digest_featured_at: nil)

      result = Episode.eligible_for_drip(user).to_a
      expect(result.first.association(:podcast).loaded?).to be(true)
      expect(result.first.association(:summary).loaded?).to be(true)
    end
  end
end
