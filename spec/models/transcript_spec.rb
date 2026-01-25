require "rails_helper"

RSpec.describe Transcript, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      transcript = build(:transcript)
      expect(transcript).to be_valid
    end

    it "requires content" do
      transcript = build(:transcript, content: nil)
      expect(transcript).not_to be_valid
      expect(transcript.errors[:content]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to episode" do
      episode = create(:episode)
      transcript = create(:transcript, episode: episode)

      expect(transcript.episode).to eq(episode)
    end
  end
end
