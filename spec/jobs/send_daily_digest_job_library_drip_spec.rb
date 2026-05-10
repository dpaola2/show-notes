require "rails_helper"

# Specs for SN-17 / M3 — SendDailyDigestJob library-drip behavior.
#
# Covers:
#   JOB-001: enqueues a digest for every digest_enabled user with ≥ 1 eligible_for_drip episode
#   JOB-002: eligibility predicate calls Episode.eligible_for_drip(user).exists?
#   No flag branching — single code path
#   Regression: a user with zero eligible episodes is NOT enqueued; digest_sent_at is NOT bumped
RSpec.describe SendDailyDigestJob, "#perform — library-drip", type: :job do
  include ActiveJob::TestHelper

  let(:podcast) { create(:podcast) }

  def make_eligible_user
    user = create(:user, digest_enabled: true)
    create(:subscription, user: user, podcast: podcast)
    ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
    create(:summary, episode: ep)
    ue = create(:user_episode, :ready, user: user, episode: ep)
    ue.update_columns(digest_featured_at: nil)
    user
  end

  describe "JOB-001: enqueues digests for eligible users (regardless of digest_sent_at)" do
    it "enqueues a digest for a user with at least one unfeatured library+ready episode" do
      user = make_eligible_user

      expect {
        described_class.perform_now
      }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
    end

    it "enqueues regardless of how recently the user was last sent (no 24h window)" do
      user = make_eligible_user
      user.update!(digest_sent_at: 30.minutes.ago)

      expect {
        described_class.perform_now
      }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
    end

    it "enqueues even when all eligible episodes were ready months ago" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 6.months.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: nil, updated_at: 6.months.ago)

      expect {
        described_class.perform_now
      }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
    end

    it "still bumps digest_sent_at when a digest is enqueued (Q15 retention)" do
      user = make_eligible_user

      freeze_time do
        described_class.perform_now
        expect(user.reload.digest_sent_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe "JOB-001 regression: zero-eligible users are NOT enqueued" do
    it "does not enqueue a digest for a user whose every library episode has already been featured" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: 1.day.ago)

      expect {
        described_class.perform_now
      }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
    end

    it "does NOT bump digest_sent_at when no digest is enqueued for a zero-eligible user" do
      user = create(:user, digest_enabled: true, digest_sent_at: 7.days.ago)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: 1.day.ago)

      original = user.digest_sent_at
      described_class.perform_now

      expect(user.reload.digest_sent_at).to be_within(1.second).of(original)
    end

    it "does not enqueue a digest for a user with only inbox episodes" do
      user = create(:user, digest_enabled: true)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast)
      create(:user_episode, user: user, episode: ep, location: :inbox, processing_status: :ready)

      expect {
        described_class.perform_now
      }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
    end
  end

  describe "JOB-002: eligibility uses Episode.eligible_for_drip(user).exists?" do
    it "delegates the eligibility predicate to Episode.eligible_for_drip(user)" do
      user = make_eligible_user

      relation = Episode.eligible_for_drip(user)
      allow(Episode).to receive(:eligible_for_drip).and_return(relation)
      allow(relation).to receive(:exists?).and_call_original

      described_class.perform_now

      expect(Episode).to have_received(:eligible_for_drip).with(user)
      expect(relation).to have_received(:exists?)
    end
  end

  describe "digest_enabled gating" do
    it "skips users with digest_enabled = false even when they have eligible episodes" do
      user = create(:user, digest_enabled: false)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: nil)

      expect {
        described_class.perform_now
      }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
    end
  end

  describe "iteration across multiple users" do
    it "enqueues for each digest_enabled user with at least one eligible episode" do
      user_a = make_eligible_user
      user_b = make_eligible_user

      expect {
        described_class.perform_now
      }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user_a, anything)
        .and have_enqueued_mail(DigestMailer, :daily_digest).with(user_b, anything)
    end
  end

  describe "no flag branching — single code path" do
    it "does not consult any users.library_drip_digest_enabled flag (column does not exist)" do
      expect(User.column_names).not_to include("library_drip_digest_enabled")
    end
  end
end
