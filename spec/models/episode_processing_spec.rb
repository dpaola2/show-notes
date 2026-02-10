require "rails_helper"

RSpec.describe Episode, type: :model do
  describe "processing_status enum" do
    it "defines processing_status with expected values" do
      expect(described_class.processing_statuses.keys).to eq(
        %w[pending downloading transcribing summarizing ready error]
      )
    end

    it "defaults to pending" do
      episode = create(:episode)
      expect(episode.processing_status).to eq("pending")
    end

    it "provides boolean query methods" do
      episode = build(:episode)
      expect(episode).to respond_to(:pending?)
      expect(episode).to respond_to(:transcribing?)
      expect(episode).to respond_to(:summarizing?)
      expect(episode).to respond_to(:ready?)
      expect(episode).to respond_to(:error?)
    end
  end

  describe "processing_error column" do
    it "stores error messages" do
      episode = create(:episode)
      episode.update!(processing_error: "AssemblyAI rate limit exceeded")
      expect(episode.reload.processing_error).to eq("AssemblyAI rate limit exceeded")
    end

    it "allows nil processing_error" do
      episode = create(:episode)
      episode.update!(processing_error: nil)
      expect(episode.reload.processing_error).to be_nil
    end
  end

  describe "last_error_at column" do
    it "stores error timestamps" do
      freeze_time do
        episode = create(:episode)
        episode.update!(last_error_at: Time.current)
        expect(episode.reload.last_error_at).to eq(Time.current)
      end
    end
  end
end
