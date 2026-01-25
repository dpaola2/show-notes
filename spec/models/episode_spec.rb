require "rails_helper"

RSpec.describe Episode, type: :model do
  describe "validations" do
    subject { build(:episode) }

    it { is_expected.to be_valid }

    it "requires guid" do
      subject.guid = nil
      expect(subject).not_to be_valid
    end

    it "requires unique guid" do
      create(:episode, guid: "same-guid")
      subject.guid = "same-guid"
      expect(subject).not_to be_valid
    end

    it "requires title" do
      subject.title = nil
      expect(subject).not_to be_valid
    end

    it "requires audio_url" do
      subject.audio_url = nil
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to podcast" do
      podcast = create(:podcast)
      episode = create(:episode, podcast: podcast)

      expect(episode.podcast).to eq(podcast)
    end

    it "has many user_episodes" do
      episode = create(:episode)
      user = create(:user)
      create(:user_episode, user: user, episode: episode)

      expect(episode.user_episodes.count).to eq(1)
    end

    it "has one transcript" do
      episode = create(:episode)
      transcript = create(:transcript, episode: episode)

      expect(episode.transcript).to eq(transcript)
    end

    it "has one summary" do
      episode = create(:episode)
      summary = create(:summary, episode: episode)

      expect(episode.summary).to eq(summary)
    end
  end

  describe "#estimated_cost_cents" do
    it "returns 0 when duration is nil" do
      episode = build(:episode, duration_seconds: nil)
      expect(episode.estimated_cost_cents).to eq(0)
    end

    it "calculates cost based on duration" do
      episode = build(:episode, duration_seconds: 3600)  # 1 hour
      # AssemblyAI: 3600 * 0.065 = 234 cents
      # Claude summarization: ~10 cents
      # Total: 244 cents
      expect(episode.estimated_cost_cents).to eq(244)
    end

    it "includes Claude summarization cost" do
      episode = build(:episode, duration_seconds: 60)  # 1 min
      # AssemblyAI: 60 * 0.065 = 3.9, ceil = 4 cents
      # Claude summarization: ~10 cents
      # Total: 14 cents
      expect(episode.estimated_cost_cents).to eq(14)
    end
  end
end
