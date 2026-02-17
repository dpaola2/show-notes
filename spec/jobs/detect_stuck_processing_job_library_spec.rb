require "rails_helper"

RSpec.describe DetectStuckProcessingJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform — Episode detection removed" do
    context "TRX-004: does not detect stuck Episodes" do
      it "does not transition stuck episodes in transcribing to error" do
        stuck_ep = create(:episode, processing_status: :transcribing)
        stuck_ep.update_column(:updated_at, 31.minutes.ago)

        described_class.perform_now

        stuck_ep.reload
        expect(stuck_ep.processing_status).to eq("transcribing")
      end

      it "does not transition stuck episodes in summarizing to error" do
        stuck_ep = create(:episode, processing_status: :summarizing)
        stuck_ep.update_column(:updated_at, 31.minutes.ago)

        described_class.perform_now

        stuck_ep.reload
        expect(stuck_ep.processing_status).to eq("summarizing")
      end

      it "does not set processing_error on stuck episodes" do
        stuck_ep = create(:episode, processing_status: :transcribing)
        stuck_ep.update_column(:updated_at, 31.minutes.ago)

        described_class.perform_now

        stuck_ep.reload
        expect(stuck_ep.processing_error).to be_nil
      end
    end

    context "M4: legacy episode-level stuck records are not touched" do
      it "runs without errors when legacy episode stuck records exist" do
        legacy_ep = create(:episode, processing_status: :transcribing)
        legacy_ep.update_column(:updated_at, 2.hours.ago)

        expect {
          described_class.perform_now
        }.not_to raise_error

        legacy_ep.reload
        expect(legacy_ep.processing_status).to eq("transcribing")
      end
    end
  end
end
