require "rails_helper"

RSpec.describe DetectStuckProcessingJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    context "ERR-002: detects stuck UserEpisodes" do
      let(:user) { create(:user) }

      it "transitions user_episodes stuck in transcribing to error" do
        stuck_ue = create(:user_episode,
          user: user,
          processing_status: :transcribing
        )
        stuck_ue.update_column(:updated_at, 31.minutes.ago)

        described_class.perform_now

        stuck_ue.reload
        expect(stuck_ue.processing_status).to eq("error")
        expect(stuck_ue.processing_error).to include("timed out")
        expect(stuck_ue.last_error_at).to be_present
      end

      it "transitions user_episodes stuck in summarizing to error" do
        stuck_ue = create(:user_episode,
          user: user,
          processing_status: :summarizing
        )
        stuck_ue.update_column(:updated_at, 31.minutes.ago)

        described_class.perform_now

        stuck_ue.reload
        expect(stuck_ue.processing_status).to eq("error")
        expect(stuck_ue.processing_error).to include("timed out")
      end

      it "does not touch user_episodes within the threshold" do
        recent_ue = create(:user_episode,
          user: user,
          processing_status: :transcribing
        )
        recent_ue.update_column(:updated_at, 29.minutes.ago)

        described_class.perform_now

        recent_ue.reload
        expect(recent_ue.processing_status).to eq("transcribing")
      end

      it "does not touch user_episodes in pending state" do
        pending_ue = create(:user_episode,
          user: user,
          processing_status: :pending
        )
        pending_ue.update_column(:updated_at, 2.hours.ago)

        described_class.perform_now

        pending_ue.reload
        expect(pending_ue.processing_status).to eq("pending")
      end

      it "does not touch user_episodes already in error state" do
        error_ue = create(:user_episode,
          user: user,
          processing_status: :error,
          processing_error: "Original error message"
        )
        error_ue.update_column(:updated_at, 2.hours.ago)

        described_class.perform_now

        error_ue.reload
        expect(error_ue.processing_error).to eq("Original error message")
      end

      it "does not touch user_episodes in ready state" do
        ready_ue = create(:user_episode,
          user: user,
          processing_status: :ready
        )
        ready_ue.update_column(:updated_at, 2.hours.ago)

        described_class.perform_now

        ready_ue.reload
        expect(ready_ue.processing_status).to eq("ready")
      end
    end

    context "idempotency" do
      let(:user) { create(:user) }

      it "can be run multiple times without creating duplicate errors" do
        stuck_ue = create(:user_episode,
          user: user,
          processing_status: :transcribing
        )
        stuck_ue.update_column(:updated_at, 31.minutes.ago)

        described_class.perform_now

        # Record the error message from first run
        stuck_ue.reload
        first_error = stuck_ue.processing_error
        first_error_at = stuck_ue.last_error_at

        # Running again should not change anything (now in error state, not transcribing)
        described_class.perform_now

        stuck_ue.reload
        expect(stuck_ue.processing_error).to eq(first_error)
        expect(stuck_ue.last_error_at).to eq(first_error_at)
      end
    end

    context "threshold boundary" do
      let(:user) { create(:user) }

      it "does not transition episodes at exactly 30 minutes" do
        boundary_ue = create(:user_episode,
          user: user,
          processing_status: :transcribing
        )
        boundary_ue.update_column(:updated_at, 30.minutes.ago)

        described_class.perform_now

        boundary_ue.reload
        # Behavior at the exact boundary depends on implementation:
        # "updated_at < ?" with STUCK_THRESHOLD.ago means exactly 30 min is NOT stuck
        expect(boundary_ue.processing_status).to eq("transcribing")
      end
    end
  end
end
