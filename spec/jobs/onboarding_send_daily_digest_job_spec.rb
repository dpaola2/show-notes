require "rails_helper"

# Tests for the REDESIGNED SendDailyDigestJob (subscription-based episode check).
# The existing send_daily_digest_job_spec.rb tests the OLD UserEpisode-based logic.
# These tests define the new contract that Stage 5 (M3) must implement.

RSpec.describe SendDailyDigestJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform (subscription-based)" do
    context "DIG-013: sends digest when user has new episodes from subscribed podcasts" do
      let!(:user) do
        user = create(:user, digest_enabled: true, digest_sent_at: 2.hours.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        create(:episode, podcast: podcast, created_at: 1.hour.ago)
        user
      end

      it "sends digest to user with new episodes" do
        expect {
          described_class.perform_now
        }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
      end

      it "updates digest_sent_at timestamp" do
        freeze_time do
          described_class.perform_now

          expect(user.reload.digest_sent_at).to eq(Time.current)
        end
      end
    end

    context "DIG-013: skips digest when user has no new episodes" do
      let!(:user_no_new) do
        user = create(:user, digest_enabled: true, digest_sent_at: 1.hour.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        # Episode created BEFORE digest_sent_at — not "new"
        create(:episode, podcast: podcast, created_at: 2.hours.ago)
        user
      end

      it "does not send digest" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_no_new)
      end

      it "does not update digest_sent_at" do
        original_sent_at = user_no_new.digest_sent_at

        described_class.perform_now

        expect(user_no_new.reload.digest_sent_at).to eq(original_sent_at)
      end
    end

    context "digest disabled" do
      let!(:user_disabled) do
        user = create(:user, digest_enabled: false, digest_sent_at: 2.hours.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        create(:episode, podcast: podcast, created_at: 1.hour.ago)
        user
      end

      it "does not send digest to users with digest_enabled: false" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_disabled)
      end
    end

    context "user with no subscriptions" do
      let!(:user_no_subs) { create(:user, digest_enabled: true) }

      it "does not send digest" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_no_subs)
      end
    end

    context "first digest (digest_sent_at is nil)" do
      let!(:user_first_digest) do
        user = create(:user, digest_enabled: true, digest_sent_at: nil)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        create(:episode, podcast: podcast, created_at: 12.hours.ago)
        user
      end

      it "sends digest using 1.day.ago as the since threshold" do
        expect {
          described_class.perform_now
        }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user_first_digest, anything)
      end
    end

    context "logging" do
      it "logs sent and skipped counts" do
        user = create(:user, digest_enabled: true, digest_sent_at: 2.hours.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        create(:episode, podcast: podcast, created_at: 1.hour.ago)

        expect(Rails.logger).to receive(:info).with(/SendDailyDigestJob.*Sent 1.*skipped 0/i)

        described_class.perform_now
      end
    end

    it "handles no users gracefully" do
      expect {
        described_class.perform_now
      }.not_to raise_error
    end
  end
end
