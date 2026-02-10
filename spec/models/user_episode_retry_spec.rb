require "rails_helper"

RSpec.describe UserEpisode, type: :model do
  describe "#retry_processing!" do
    let(:user) { create(:user) }
    let(:episode) { create(:episode) }
    let!(:user_episode) do
      create(:user_episode,
        user: user,
        episode: episode,
        location: :library,
        processing_status: :error,
        processing_error: "AssemblyAI rate limit exceeded",
        retry_count: 3,
        next_retry_at: 5.minutes.from_now,
        last_error_at: 1.minute.ago
      )
    end

    it "resets processing_status to pending" do
      user_episode.retry_processing!
      expect(user_episode.reload.processing_status).to eq("pending")
    end

    it "clears retry_count to 0" do
      user_episode.retry_processing!
      expect(user_episode.reload.retry_count).to eq(0)
    end

    it "clears next_retry_at" do
      user_episode.retry_processing!
      expect(user_episode.reload.next_retry_at).to be_nil
    end

    it "clears processing_error" do
      user_episode.retry_processing!
      expect(user_episode.reload.processing_error).to be_nil
    end

    it "does not change the location" do
      user_episode.retry_processing!
      expect(user_episode.reload.location).to eq("library")
    end

    context "when called on an inbox episode" do
      let!(:inbox_episode) do
        create(:user_episode,
          user: user,
          location: :inbox,
          processing_status: :error,
          processing_error: "Network timeout",
          retry_count: 1,
          next_retry_at: 2.minutes.from_now
        )
      end

      it "resets state without changing location" do
        inbox_episode.retry_processing!

        inbox_episode.reload
        expect(inbox_episode.processing_status).to eq("pending")
        expect(inbox_episode.location).to eq("inbox")
        expect(inbox_episode.retry_count).to eq(0)
        expect(inbox_episode.processing_error).to be_nil
      end
    end
  end
end
