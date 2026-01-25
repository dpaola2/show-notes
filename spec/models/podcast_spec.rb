require "rails_helper"

RSpec.describe Podcast, type: :model do
  describe "validations" do
    subject { build(:podcast) }

    it { is_expected.to be_valid }

    it "requires guid" do
      subject.guid = nil
      expect(subject).not_to be_valid
    end

    it "requires unique guid" do
      create(:podcast, guid: "same-guid")
      subject.guid = "same-guid"
      expect(subject).not_to be_valid
    end

    it "requires title" do
      subject.title = nil
      expect(subject).not_to be_valid
    end

    it "requires feed_url" do
      subject.feed_url = nil
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "has many subscriptions" do
      podcast = create(:podcast)
      user = create(:user)
      create(:subscription, user: user, podcast: podcast)

      expect(podcast.subscriptions.count).to eq(1)
    end

    it "has many users through subscriptions" do
      podcast = create(:podcast)
      user = create(:user)
      create(:subscription, user: user, podcast: podcast)

      expect(podcast.users).to include(user)
    end

    it "has many episodes" do
      podcast = create(:podcast)
      create(:episode, podcast: podcast)
      create(:episode, podcast: podcast)

      expect(podcast.episodes.count).to eq(2)
    end

    it "destroys subscriptions when destroyed" do
      podcast = create(:podcast)
      user = create(:user)
      create(:subscription, user: user, podcast: podcast)

      expect { podcast.destroy }.to change(Subscription, :count).by(-1)
    end

    it "destroys episodes when destroyed" do
      podcast = create(:podcast)
      create(:episode, podcast: podcast)

      expect { podcast.destroy }.to change(Episode, :count).by(-1)
    end
  end
end
