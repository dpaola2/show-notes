require "rails_helper"

RSpec.describe ApiToken, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      api_token = build(:api_token)
      expect(api_token).to be_valid
    end

    it "requires token_digest" do
      api_token = build(:api_token, token_digest: nil)
      expect(api_token).not_to be_valid
      expect(api_token.errors[:token_digest]).to include("can't be blank")
    end

    it "requires unique token_digest" do
      existing = create(:api_token)
      duplicate = build(:api_token, token_digest: existing.token_digest)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:token_digest]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "belongs to a user" do
      api_token = create(:api_token)
      expect(api_token.user).to be_a(User)
    end
  end

  describe ".generate_for" do
    let(:user) { create(:user) }

    it "returns an ApiToken and a plaintext token" do
      api_token, plaintext = described_class.generate_for(user)

      expect(api_token).to be_a(ApiToken)
      expect(api_token).to be_persisted
      expect(plaintext).to be_a(String)
      expect(plaintext.length).to be >= 32
    end

    it "stores the SHA-256 digest, not the plaintext" do
      api_token, plaintext = described_class.generate_for(user)

      expect(api_token.token_digest).to eq(Digest::SHA256.hexdigest(plaintext))
      expect(api_token.token_digest).not_to eq(plaintext)
    end

    it "creates a token belonging to the user" do
      api_token, _plaintext = described_class.generate_for(user)

      expect(api_token.user).to eq(user)
    end

    it "generates unique tokens each time" do
      _token1, plaintext1 = described_class.generate_for(user)
      _token2, plaintext2 = described_class.generate_for(user)

      expect(plaintext1).not_to eq(plaintext2)
    end
  end

  describe ".find_by_plaintext" do
    let(:user) { create(:user) }

    it "finds a token by its plaintext value" do
      api_token, plaintext = described_class.generate_for(user)

      found = described_class.find_by_plaintext(plaintext)
      expect(found).to eq(api_token)
    end

    it "returns nil for an invalid plaintext" do
      described_class.generate_for(user)

      expect(described_class.find_by_plaintext("invalid-token")).to be_nil
    end

    it "returns nil for blank plaintext" do
      expect(described_class.find_by_plaintext("")).to be_nil
      expect(described_class.find_by_plaintext(nil)).to be_nil
    end
  end

  describe "#touch_last_used!" do
    it "updates last_used_at to the current time" do
      api_token = create(:api_token)
      expect(api_token.last_used_at).to be_nil

      freeze_time do
        api_token.touch_last_used!
        expect(api_token.reload.last_used_at).to be_within(1.second).of(Time.current)
      end
    end

    it "does not change updated_at" do
      api_token = create(:api_token)
      original_updated_at = api_token.updated_at

      travel_to 1.hour.from_now do
        api_token.touch_last_used!
        expect(api_token.reload.updated_at).to eq(original_updated_at)
      end
    end
  end

  describe "user association dependency" do
    it "destroys api_tokens when user is destroyed" do
      user = create(:user)
      api_token, _plaintext = described_class.generate_for(user)

      user.destroy!

      expect(described_class.find_by(id: api_token.id)).to be_nil
    end
  end
end
