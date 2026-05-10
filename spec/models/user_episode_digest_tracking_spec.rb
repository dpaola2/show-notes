require "rails_helper"

# Specs for SN-17 / M2 — UserEpisode digest tracking helpers and scopes.
#
# Covers:
#   TRK-001: #mark_digest_featured! sets digest_featured_at when nil; idempotent on second call
#   TRK-002: #mark_digest_compact_appearance! always overwrites digest_last_appeared_at
#   .unfeatured scope returns rows where digest_featured_at IS NULL
#   move_to_library! must NOT touch digest_featured_at or digest_last_appeared_at
RSpec.describe UserEpisode, type: :model do
  describe "TRK-001: #mark_digest_featured!" do
    it "sets digest_featured_at when currently nil" do
      ue = create(:user_episode, :ready)
      ue.update_columns(digest_featured_at: nil)

      stamp_time = Time.current.change(usec: 0)
      ue.mark_digest_featured!(at: stamp_time)

      expect(ue.reload.digest_featured_at).to be_within(1.second).of(stamp_time)
    end

    it "defaults `at:` to Time.current" do
      ue = create(:user_episode, :ready)
      ue.update_columns(digest_featured_at: nil)

      freeze_time do
        ue.mark_digest_featured!
        expect(ue.reload.digest_featured_at).to be_within(1.second).of(Time.current)
      end
    end

    it "is idempotent — does not overwrite an existing digest_featured_at" do
      original_time = 5.days.ago.change(usec: 0)
      ue = create(:user_episode, :ready)
      ue.update_columns(digest_featured_at: original_time)

      ue.mark_digest_featured!(at: Time.current)

      expect(ue.reload.digest_featured_at).to be_within(1.second).of(original_time)
    end
  end

  describe "TRK-002: #mark_digest_compact_appearance!" do
    it "sets digest_last_appeared_at when currently nil" do
      ue = create(:user_episode, :ready)
      ue.update_columns(digest_last_appeared_at: nil)

      stamp_time = Time.current.change(usec: 0)
      ue.mark_digest_compact_appearance!(at: stamp_time)

      expect(ue.reload.digest_last_appeared_at).to be_within(1.second).of(stamp_time)
    end

    it "always overwrites digest_last_appeared_at on subsequent calls" do
      ue = create(:user_episode, :ready)
      ue.update_columns(digest_last_appeared_at: 7.days.ago.change(usec: 0))

      newer_time = Time.current.change(usec: 0)
      ue.mark_digest_compact_appearance!(at: newer_time)

      expect(ue.reload.digest_last_appeared_at).to be_within(1.second).of(newer_time)
    end

    it "defaults `at:` to Time.current" do
      ue = create(:user_episode, :ready)
      ue.update_columns(digest_last_appeared_at: nil)

      freeze_time do
        ue.mark_digest_compact_appearance!
        expect(ue.reload.digest_last_appeared_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe ".unfeatured scope" do
    it "returns UserEpisodes where digest_featured_at IS NULL" do
      featured = create(:user_episode, :ready)
      featured.update_columns(digest_featured_at: 1.day.ago)

      unfeatured = create(:user_episode, :ready)
      unfeatured.update_columns(digest_featured_at: nil)

      expect(UserEpisode.unfeatured).to include(unfeatured)
      expect(UserEpisode.unfeatured).not_to include(featured)
    end
  end

  describe "#move_to_library! preserves digest tracking columns" do
    it "does NOT clear digest_featured_at when called on a previously-featured UserEpisode" do
      ue = create(:user_episode, :in_archive, processing_status: :ready)
      stamp = 3.days.ago.change(usec: 0)
      ue.update_columns(digest_featured_at: stamp, digest_last_appeared_at: stamp)

      ue.move_to_library!

      expect(ue.reload.digest_featured_at).to be_within(1.second).of(stamp)
    end

    it "does NOT clear digest_last_appeared_at on move_to_library!" do
      ue = create(:user_episode, :in_archive, processing_status: :ready)
      stamp = 3.days.ago.change(usec: 0)
      ue.update_columns(digest_last_appeared_at: stamp)

      ue.move_to_library!

      expect(ue.reload.digest_last_appeared_at).to be_within(1.second).of(stamp)
    end

    it "moves the UserEpisode back into the library while preserving digest_featured_at" do
      user = create(:user)
      podcast = create(:podcast)
      episode = create(:episode, podcast: podcast)
      create(:summary, episode: episode)

      ue = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)
      ue.update_columns(digest_featured_at: 1.week.ago)

      ue.move_to_library!

      # The episode should NOT re-enter the eligible_for_drip pool because its
      # digest_featured_at is still non-nil.
      expect(Episode.eligible_for_drip(user)).not_to include(episode)
    end
  end
end
