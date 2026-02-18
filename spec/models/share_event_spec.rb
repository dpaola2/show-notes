require "rails_helper"

RSpec.describe ShareEvent, type: :model do
  describe "validations" do
    subject { build(:share_event) }

    it { is_expected.to be_valid }

    it "requires share_target" do
      subject.share_target = nil
      expect(subject).not_to be_valid
    end

    it "validates share_target inclusion" do
      subject.share_target = "instagram"
      expect(subject).not_to be_valid
    end

    it "allows clipboard share_target" do
      subject.share_target = "clipboard"
      expect(subject).to be_valid
    end

    it "allows twitter share_target" do
      subject.share_target = "twitter"
      expect(subject).to be_valid
    end

    it "allows linkedin share_target" do
      subject.share_target = "linkedin"
      expect(subject).to be_valid
    end

    it "allows native share_target" do
      subject.share_target = "native"
      expect(subject).to be_valid
    end
  end

  describe "associations" do
    it "belongs to episode" do
      episode = create(:episode)
      event = create(:share_event, episode: episode)
      expect(event.episode).to eq(episode)
    end

    it "belongs to user (optional)" do
      user = create(:user)
      event = create(:share_event, :with_user, user: user)
      expect(event.user).to eq(user)
    end

    it "allows nil user for unauthenticated shares" do
      event = create(:share_event, user: nil)
      expect(event.user).to be_nil
    end
  end

  describe "scopes" do
    let(:episode) { create(:episode) }
    let(:other_episode) { create(:episode) }
    let!(:clipboard_event) { create(:share_event, :clipboard, episode: episode) }
    let!(:twitter_event) { create(:share_event, :twitter, episode: episode) }
    let!(:other_event) { create(:share_event, :clipboard, episode: other_episode) }

    describe ".for_episode" do
      it "returns share events for the given episode" do
        expect(ShareEvent.for_episode(episode)).to contain_exactly(clipboard_event, twitter_event)
      end

      it "excludes share events for other episodes" do
        expect(ShareEvent.for_episode(episode)).not_to include(other_event)
      end
    end

    describe ".by_target" do
      it "returns share events with the given target" do
        expect(ShareEvent.by_target("clipboard")).to contain_exactly(clipboard_event, other_event)
      end

      it "excludes share events with different targets" do
        expect(ShareEvent.by_target("clipboard")).not_to include(twitter_event)
      end
    end
  end
end
