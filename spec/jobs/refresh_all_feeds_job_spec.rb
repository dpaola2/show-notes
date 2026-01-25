require "rails_helper"

RSpec.describe RefreshAllFeedsJob, type: :job do
  describe "#perform" do
    it "enqueues FetchPodcastFeedJob for each podcast with subscribers" do
      podcast1 = create(:podcast)
      podcast2 = create(:podcast)
      podcast3 = create(:podcast) # No subscribers

      user = create(:user)
      create(:subscription, user: user, podcast: podcast1)
      create(:subscription, user: user, podcast: podcast2)

      expect {
        described_class.perform_now
      }.to have_enqueued_job(FetchPodcastFeedJob).twice

      expect(FetchPodcastFeedJob).to have_been_enqueued.with(podcast1.id)
      expect(FetchPodcastFeedJob).to have_been_enqueued.with(podcast2.id)
    end

    it "does not enqueue jobs for podcasts without subscribers" do
      podcast = create(:podcast) # No subscribers

      expect {
        described_class.perform_now
      }.not_to have_enqueued_job(FetchPodcastFeedJob)
    end

    it "handles the case when no podcasts have subscribers" do
      expect {
        described_class.perform_now
      }.not_to raise_error
    end

    it "only enqueues once per podcast even with multiple subscribers" do
      podcast = create(:podcast)
      user1 = create(:user)
      user2 = create(:user)
      create(:subscription, user: user1, podcast: podcast)
      create(:subscription, user: user2, podcast: podcast)

      expect {
        described_class.perform_now
      }.to have_enqueued_job(FetchPodcastFeedJob).once
    end
  end
end
