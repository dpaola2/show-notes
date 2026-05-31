require "rails_helper"

RSpec.describe Analytics do
  describe "when PostHog is not configured (POSTHOG_CLIENT is nil)" do
    it "capture is a safe no-op that returns nil and does not raise" do
      expect(POSTHOG_CLIENT).to be_nil
      expect { Analytics.capture(distinct_id: "abc", event: "test_event", properties: { a: 1 }) }
        .not_to raise_error
    end

    it "identify is a safe no-op" do
      expect { Analytics.identify(distinct_id: "abc", properties: { a: 1 }) }.not_to raise_error
    end
  end

  describe "when a client is present" do
    let(:client) { instance_double(PostHog::Client) }

    before { stub_const("POSTHOG_CLIENT", client) }

    it "forwards capture with a stringified distinct_id and compacted properties" do
      expect(client).to receive(:capture).with(
        distinct_id: "42",
        event: "thing_happened",
        properties: { platform: "web" }
      )

      Analytics.capture(distinct_id: 42, event: "thing_happened", properties: { platform: "web", nope: nil })
    end

    it "swallows client errors so analytics never breaks a request" do
      allow(client).to receive(:capture).and_raise(StandardError, "boom")
      expect { Analytics.capture(distinct_id: "1", event: "x") }.not_to raise_error
    end
  end
end
