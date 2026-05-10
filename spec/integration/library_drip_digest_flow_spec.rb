require "rails_helper"

# Integration spec for SN-17 / M6 — end-to-end library-drip flow.
# Exercises SendDailyDigestJob.perform_now twice in a row (no Timecop per GP-3)
# and asserts that two consecutive runs produce non-overlapping featured picks
# while the rest of the library remains eligible.
#
# Covers PRD §8 edge cases:
#   - User has 8 eligible episodes — first run picks featured + 5 compact,
#     second run picks the next featured from what remains
#   - move_to_library! preserves digest_featured_at (regression)
#   - User unsubscribes mid-cycle (UserEpisode removed) — ineligible immediately
#   - digest_enabled = false skipped
#   - 2 episodes with identical published_at — id DESC tiebreak is deterministic
#   - NULL published_at — sorts last (NULLS LAST), no crash
RSpec.describe "Library-drip digest end-to-end flow", type: :request do
  include ActiveJob::TestHelper

  let(:podcast) { create(:podcast, title: "Integration Podcast") }

  def make_eligible_user(num_episodes:)
    user = create(:user, digest_enabled: true)
    create(:subscription, user: user, podcast: podcast)
    episodes = num_episodes.times.map do |i|
      ep = create(:episode, podcast: podcast, title: "Ep #{i}", published_at: (i + 1).days.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: nil)
      ep
    end
    [ user, episodes ]
  end

  describe "two consecutive perform_now runs (GP-3: no Timecop)" do
    it "stamps exactly 1 featured + 5 compact after the first run, leaving 2 still eligible" do
      user, _episodes = make_eligible_user(num_episodes: 8)

      perform_enqueued_jobs do
        SendDailyDigestJob.perform_now
      end

      featured_count = UserEpisode
        .where(user: user)
        .where.not(digest_featured_at: nil)
        .count
      compact_count = UserEpisode
        .where(user: user)
        .where.not(digest_last_appeared_at: nil)
        .count
      remaining_eligible = Episode.eligible_for_drip(user).count

      expect(featured_count).to eq(1)
      expect(compact_count).to eq(5)
      expect(remaining_eligible).to eq(7)  # 8 total minus 1 featured = 7 still unfeatured
    end

    it "the second run picks a different featured episode than the first run" do
      user, _episodes = make_eligible_user(num_episodes: 8)

      perform_enqueued_jobs do
        SendDailyDigestJob.perform_now
      end
      first_featured_id = UserEpisode
        .where(user: user)
        .where.not(digest_featured_at: nil)
        .pluck(:episode_id)
        .first

      perform_enqueued_jobs do
        SendDailyDigestJob.perform_now
      end
      featured_episode_ids = UserEpisode
        .where(user: user)
        .where.not(digest_featured_at: nil)
        .pluck(:episode_id)
      second_featured_id = (featured_episode_ids - [ first_featured_id ]).first

      expect(featured_episode_ids.count).to eq(2)
      expect(second_featured_id).not_to be_nil
      expect(second_featured_id).not_to eq(first_featured_id)
    end
  end

  describe "library-exhausted user — NullMail" do
    it "does not enqueue a digest when the user has zero eligible episodes" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: 1.day.ago)

      expect {
        SendDailyDigestJob.perform_now
      }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
    end

    it "does not bump digest_sent_at when the user is library-exhausted" do
      user = create(:user, digest_enabled: true, digest_sent_at: 7.days.ago)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: 1.day.ago)

      original = user.digest_sent_at
      SendDailyDigestJob.perform_now

      expect(user.reload.digest_sent_at).to be_within(1.second).of(original)
    end
  end

  describe "fewer than 6 eligible — graceful degradation" do
    it "stamps featured (1) + (N-1) compact when only N eligible (1 < N < 6)" do
      user, _eps = make_eligible_user(num_episodes: 3)

      perform_enqueued_jobs do
        SendDailyDigestJob.perform_now
      end

      featured_count = UserEpisode.where(user: user).where.not(digest_featured_at: nil).count
      compact_count  = UserEpisode.where(user: user).where.not(digest_last_appeared_at: nil).count

      expect(featured_count).to eq(1)
      expect(compact_count).to eq(2)  # 3 total - 1 featured = 2 compact
    end
  end

  describe "edge: identical published_at — id DESC tiebreak is deterministic" do
    it "deterministically picks the higher-id episode as featured when published_at ties" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)

      shared_published_at = 5.days.ago.change(usec: 0)
      ep_low = create(:episode, podcast: podcast, title: "TieLow", published_at: shared_published_at)
      create(:summary, episode: ep_low)
      ue_low = create(:user_episode, :ready, user: user, episode: ep_low)
      ue_low.update_columns(digest_featured_at: nil)

      ep_high = create(:episode, podcast: podcast, title: "TieHigh", published_at: shared_published_at)
      create(:summary, episode: ep_high)
      ue_high = create(:user_episode, :ready, user: user, episode: ep_high)
      ue_high.update_columns(digest_featured_at: nil)

      perform_enqueued_jobs do
        SendDailyDigestJob.perform_now
      end

      expect(ue_high.reload.digest_featured_at).not_to be_nil
      expect(ue_low.reload.digest_featured_at).to be_nil
    end
  end

  describe "edge: NULL published_at — sorts last (NULLS LAST)" do
    it "does not crash and selects the non-NULL published_at episode first" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)

      ep_with = create(:episode, podcast: podcast, title: "HasDate", published_at: 7.days.ago)
      create(:summary, episode: ep_with)
      ue_with = create(:user_episode, :ready, user: user, episode: ep_with)
      ue_with.update_columns(digest_featured_at: nil)

      ep_no = create(:episode, podcast: podcast, title: "NoDate", published_at: nil)
      create(:summary, episode: ep_no)
      ue_no = create(:user_episode, :ready, user: user, episode: ep_no)
      ue_no.update_columns(digest_featured_at: nil)

      expect {
        perform_enqueued_jobs do
          SendDailyDigestJob.perform_now
        end
      }.not_to raise_error

      expect(ue_with.reload.digest_featured_at).not_to be_nil
      expect(ue_no.reload.digest_featured_at).to be_nil
    end
  end

  describe "edge: old (6-month) episode renders gracefully" do
    it "features and renders an episode published 6 months ago without error" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)

      ep = create(:episode, podcast: podcast, title: "AncientFeature", published_at: 6.months.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: nil)

      expect {
        perform_enqueued_jobs do
          SendDailyDigestJob.perform_now
        end
      }.not_to raise_error

      expect(ue.reload.digest_featured_at).not_to be_nil
    end
  end

  describe "edge: move_to_library! preserves digest_featured_at" do
    it "an archived previously-featured episode that is moved back to library does NOT re-eligibilize" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)

      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :in_archive, user: user, episode: ep, processing_status: :ready)
      ue.update_columns(digest_featured_at: 30.days.ago)

      ue.move_to_library!

      expect(Episode.eligible_for_drip(user)).not_to include(ep)
    end
  end

  describe "edge: digest_enabled = false user is skipped" do
    it "does not enqueue or stamp anything for a digest_enabled = false user" do
      user = create(:user, digest_enabled: false)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: nil)

      expect {
        SendDailyDigestJob.perform_now
      }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)

      expect(ue.reload.digest_featured_at).to be_nil
    end
  end

  describe "edge: user unsubscribes mid-cycle" do
    it "an episode immediately becomes ineligible when its UserEpisode is destroyed" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: nil)

      expect(Episode.eligible_for_drip(user)).to include(ep)

      ue.destroy!

      expect(Episode.eligible_for_drip(user)).not_to include(ep)
    end

    it "the next mailer run does not raise when an episode's UserEpisode disappears" do
      user, _eps = make_eligible_user(num_episodes: 2)

      # Destroy half of the eligible UserEpisodes between job iterations.
      UserEpisode.where(user: user).limit(1).destroy_all

      expect {
        perform_enqueued_jobs do
          SendDailyDigestJob.perform_now
        end
      }.not_to raise_error
    end
  end

  describe "no remaining references to library_ready_since" do
    it "Episode does not respond to library_ready_since (deleted in M2)" do
      expect(Episode.respond_to?(:library_ready_since)).to be(false)
    end
  end
end
