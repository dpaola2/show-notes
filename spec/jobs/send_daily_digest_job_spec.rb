require "rails_helper"

# These tests cover the redesigned subscription-based digest job.
# The comprehensive test suite is in onboarding_send_daily_digest_job_spec.rb;
# this file provides basic sanity checks for the core job behavior.

RSpec.describe SendDailyDigestJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    context "with users who have digest enabled and new episodes" do
      let!(:user) do
        user = create(:user, digest_enabled: true, digest_sent_at: 2.hours.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        create(:episode, podcast: podcast, created_at: 1.hour.ago)
        user
      end

      it "sends digest to users with new subscribed episodes" do
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

    context "with users who have no subscriptions" do
      let!(:user_no_content) { create(:user, digest_enabled: true) }

      it "does not send digest" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_no_content)
      end

      it "does not update digest_sent_at" do
        described_class.perform_now

        expect(user_no_content.reload.digest_sent_at).to be_nil
      end
    end

    context "with users who have digest disabled" do
      let!(:user_disabled) do
        user = create(:user, digest_enabled: false, digest_sent_at: 2.hours.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        create(:episode, podcast: podcast, created_at: 1.hour.ago)
        user
      end

      it "does not send digest" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_disabled)
      end
    end

    it "handles no users gracefully" do
      expect {
        described_class.perform_now
      }.not_to raise_error
    end
  end
end
