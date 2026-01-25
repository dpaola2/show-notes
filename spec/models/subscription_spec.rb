require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      subscription = build(:subscription)
      expect(subscription).to be_valid
    end

    it "requires unique user_id + podcast_id combination" do
      existing = create(:subscription)
      duplicate = build(:subscription, user: existing.user, podcast: existing.podcast)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "belongs to user" do
      user = create(:user)
      subscription = create(:subscription, user: user)

      expect(subscription.user).to eq(user)
    end

    it "belongs to podcast" do
      podcast = create(:podcast)
      subscription = create(:subscription, podcast: podcast)

      expect(subscription.podcast).to eq(podcast)
    end
  end
end
