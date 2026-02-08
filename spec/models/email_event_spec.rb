require "rails_helper"

RSpec.describe EmailEvent, type: :model do
  describe "validations" do
    subject { build(:email_event) }

    it { is_expected.to be_valid }

    it "requires token" do
      subject.token = nil
      expect(subject).not_to be_valid
    end

    it "requires unique token" do
      create(:email_event, token: "duplicate-token")
      subject.token = "duplicate-token"
      expect(subject).not_to be_valid
    end

    it "requires event_type" do
      subject.event_type = nil
      expect(subject).not_to be_valid
    end

    it "validates event_type inclusion" do
      subject.event_type = "invalid"
      expect(subject).not_to be_valid
    end

    it "allows open event_type" do
      subject.event_type = "open"
      subject.link_type = nil
      subject.episode = nil
      expect(subject).to be_valid
    end

    it "allows click event_type" do
      subject.event_type = "click"
      expect(subject).to be_valid
    end

    it "validates link_type inclusion when present" do
      subject.link_type = "invalid"
      expect(subject).not_to be_valid
    end

    it "allows summary link_type" do
      subject.link_type = "summary"
      expect(subject).to be_valid
    end

    it "allows listen link_type" do
      subject.link_type = "listen"
      expect(subject).to be_valid
    end

    it "allows nil link_type for open events" do
      subject.event_type = "open"
      subject.link_type = nil
      subject.episode = nil
      expect(subject).to be_valid
    end

    it "requires digest_date" do
      subject.digest_date = nil
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to user" do
      user = create(:user)
      event = create(:email_event, user: user)
      expect(event.user).to eq(user)
    end

    it "belongs to episode (optional)" do
      episode = create(:episode)
      event = create(:email_event, episode: episode)
      expect(event.episode).to eq(episode)
    end

    it "allows nil episode for open events" do
      event = create(:email_event, :open)
      expect(event.episode).to be_nil
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:episode) { create(:episode) }

    let!(:open_event) { create(:email_event, :open, user: user, digest_date: "2026-02-07") }
    let!(:click_event) { create(:email_event, :click_summary, user: user, episode: episode, digest_date: "2026-02-07") }
    let!(:triggered_event) { create(:email_event, :click_listen, :triggered, user: user, episode: episode, digest_date: "2026-02-07") }
    let!(:old_event) { create(:email_event, :open, :triggered, user: user, digest_date: "2026-02-06") }

    describe ".opens" do
      it "returns only open events" do
        expect(EmailEvent.opens).to contain_exactly(open_event, old_event)
      end
    end

    describe ".clicks" do
      it "returns only click events" do
        expect(EmailEvent.clicks).to contain_exactly(click_event, triggered_event)
      end
    end

    describe ".triggered" do
      it "returns only events with triggered_at set" do
        expect(EmailEvent.triggered).to contain_exactly(triggered_event, old_event)
      end
    end

    describe ".for_date" do
      it "returns events for a specific date" do
        expect(EmailEvent.for_date(Date.parse("2026-02-07"))).to contain_exactly(open_event, click_event, triggered_event)
      end

      it "excludes events from other dates" do
        expect(EmailEvent.for_date(Date.parse("2026-02-07"))).not_to include(old_event)
      end
    end
  end

  describe "#triggered?" do
    it "returns false when triggered_at is nil" do
      event = build(:email_event, triggered_at: nil)
      expect(event.triggered?).to be false
    end

    it "returns true when triggered_at is set" do
      event = build(:email_event, :triggered)
      expect(event.triggered?).to be true
    end
  end

  describe "#trigger!" do
    let(:event) { create(:email_event) }

    it "sets triggered_at to current time" do
      freeze_time do
        event.trigger!
        expect(event.reload.triggered_at).to eq(Time.current)
      end
    end

    it "sets user_agent from request" do
      mock_request = double(user_agent: "TestBrowser/1.0")
      event.trigger!(request: mock_request)
      expect(event.reload.user_agent).to eq("TestBrowser/1.0")
    end

    it "does not re-trigger an already triggered event" do
      original_time = 1.hour.ago
      event.update!(triggered_at: original_time)

      event.trigger!
      expect(event.reload.triggered_at).to eq(original_time)
    end

    it "handles nil request gracefully" do
      event.trigger!(request: nil)
      expect(event.reload.triggered_at).to be_present
      expect(event.reload.user_agent).to be_nil
    end
  end
end
