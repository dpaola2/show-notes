require "rails_helper"

RSpec.describe SendDailyDigestJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    context "with users who have digest enabled" do
      let!(:user_with_inbox) do
        user = create(:user, digest_enabled: true)
        episode = create(:episode)
        create(:user_episode, user: user, episode: episode, location: :inbox)
        user
      end

      let!(:user_with_library) do
        user = create(:user, digest_enabled: true)
        episode = create(:episode)
        create(:user_episode, user: user, episode: episode, location: :library, processing_status: :ready, updated_at: 1.hour.ago)
        user
      end

      it "sends digest to users with inbox episodes" do
        expect {
          described_class.perform_now
        }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user_with_inbox)
      end

      it "sends digest to users with recent library episodes" do
        expect {
          described_class.perform_now
        }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user_with_library)
      end

      it "updates digest_sent_at timestamp" do
        freeze_time do
          described_class.perform_now

          expect(user_with_inbox.reload.digest_sent_at).to eq(Time.current)
          expect(user_with_library.reload.digest_sent_at).to eq(Time.current)
        end
      end
    end

    context "with users who have no content" do
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
        user = create(:user, digest_enabled: false)
        episode = create(:episode)
        create(:user_episode, user: user, episode: episode, location: :inbox)
        user
      end

      it "does not send digest" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_disabled)
      end
    end

    context "with old library episodes" do
      let!(:user_old_library) do
        user = create(:user, digest_enabled: true)
        episode = create(:episode)
        create(:user_episode, user: user, episode: episode, location: :library, processing_status: :ready, updated_at: 3.days.ago)
        user
      end

      it "does not send digest for library episodes older than 2 days" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_old_library)
      end
    end

    context "with pending library episodes" do
      let!(:user_pending) do
        user = create(:user, digest_enabled: true)
        episode = create(:episode)
        create(:user_episode, user: user, episode: episode, location: :library, processing_status: :pending, updated_at: 1.hour.ago)
        user
      end

      it "does not send digest for non-ready library episodes" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest).with(user_pending)
      end
    end

    it "handles no users gracefully" do
      expect {
        described_class.perform_now
      }.not_to raise_error
    end
  end
end
