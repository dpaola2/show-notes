require "rails_helper"

RSpec.describe SendDailyDigestJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform — library-scoped eligibility" do
    context "DIG-001: sends digest based on library episodes" do
      let!(:user) do
        user = create(:user, digest_enabled: true, digest_sent_at: 2.hours.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        ep = create(:episode, podcast: podcast, created_at: 3.hours.ago)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        user
      end

      it "sends digest when library episodes are ready within window" do
        expect {
          described_class.perform_now
        }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
      end
    end

    context "DIG-001: does not send digest for inbox-only episodes" do
      let!(:user) do
        user = create(:user, digest_enabled: true, digest_sent_at: 2.hours.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        ep = create(:episode, podcast: podcast, created_at: 1.hour.ago)
        create(:user_episode, user: user, episode: ep, location: :inbox)
        user
      end

      it "does not send digest when episodes are only in inbox" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest)
      end
    end

    context "DIG-002: 24-hour cap includes recent library episodes" do
      let!(:user) do
        user = create(:user, digest_enabled: true, digest_sent_at: 3.days.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        ep = create(:episode, podcast: podcast, created_at: 4.days.ago)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 12.hours.ago)
        user
      end

      it "sends digest for library episodes within 24-hour cap" do
        expect {
          described_class.perform_now
        }.to have_enqueued_mail(DigestMailer, :daily_digest).with(user, anything)
      end
    end

    context "DIG-002: 24-hour cap excludes old library episodes" do
      let!(:user) do
        user = create(:user, digest_enabled: true, digest_sent_at: 5.days.ago)
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
        ep = create(:episode, podcast: podcast, created_at: 2.days.ago)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 2.days.ago)
        user
      end

      it "does not send digest when library episodes are beyond 24-hour cap" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_mail(DigestMailer, :daily_digest)
      end
    end
  end
end
