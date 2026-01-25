require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to be_valid }

    it "requires email" do
      subject.email = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to include("can't be blank")
    end

    it "requires unique email" do
      create(:user, email: "test@example.com")
      subject.email = "test@example.com"
      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to include("has already been taken")
    end

    it "validates email format" do
      subject.email = "not-an-email"
      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to include("is invalid")
    end
  end

  describe "associations" do
    it "has many subscriptions" do
      user = create(:user)
      podcast = create(:podcast)
      create(:subscription, user: user, podcast: podcast)

      expect(user.subscriptions.count).to eq(1)
    end

    it "has many podcasts through subscriptions" do
      user = create(:user)
      podcast = create(:podcast)
      create(:subscription, user: user, podcast: podcast)

      expect(user.podcasts).to include(podcast)
    end

    it "has many user_episodes" do
      user = create(:user)
      episode = create(:episode)
      create(:user_episode, user: user, episode: episode)

      expect(user.user_episodes.count).to eq(1)
    end
  end

  describe "#generate_magic_token!" do
    it "generates a token and sets expiry" do
      user = create(:user)
      token = user.generate_magic_token!

      expect(token).to be_present
      expect(user.magic_token).to eq(token)
      expect(user.magic_token_expires_at).to be > Time.current
      expect(user.magic_token_expires_at).to be < 20.minutes.from_now
    end
  end

  describe "#clear_magic_token!" do
    it "clears the token and expiry" do
      user = create(:user, :with_magic_token)
      user.clear_magic_token!

      expect(user.magic_token).to be_nil
      expect(user.magic_token_expires_at).to be_nil
    end
  end

  describe "#magic_token_valid?" do
    it "returns true for valid unexpired token" do
      user = create(:user, :with_magic_token)
      expect(user.magic_token_valid?(user.magic_token)).to be true
    end

    it "returns false for wrong token" do
      user = create(:user, :with_magic_token)
      expect(user.magic_token_valid?("wrong-token")).to be false
    end

    it "returns false for expired token" do
      user = create(:user, :with_expired_token)
      expect(user.magic_token_valid?(user.magic_token)).to be false
    end

    it "returns false when no token set" do
      user = create(:user)
      expect(user.magic_token_valid?("any-token")).to be false
    end
  end
end
