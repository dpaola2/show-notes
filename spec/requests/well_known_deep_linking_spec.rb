require "rails_helper"

RSpec.describe "Well-Known: Deep Linking AASA Patterns", type: :request do
  describe "GET /.well-known/apple-app-site-association" do
    let(:parsed) do
      get "/.well-known/apple-app-site-association"
      JSON.parse(response.body)
    end

    let(:components) { parsed.dig("applinks", "details", 0, "components") }

    context "AASA-001: contains /e/* component for public episode URLs" do
      it "includes a component matching /e/*" do
        episode_component = components.find { |c| c["/"] == "/e/*" }
        expect(episode_component).to be_present
      end
    end

    context "AASA-002: contains /t/* component for tracking URLs" do
      it "includes a component matching /t/*" do
        tracking_component = components.find { |c| c["/"] == "/t/*" && !c.key?("exclude") }
        expect(tracking_component).to be_present
      end
    end

    context "AASA-003: pixel.gif exclusion rule before /t/* rule" do
      it "includes a pixel.gif exclusion rule" do
        pixel_exclusion = components.find { |c| c["/"] == "/t/*/pixel.gif" && c["exclude"] == true }
        expect(pixel_exclusion).to be_present
      end

      it "places the pixel.gif exclusion BEFORE the /t/* inclusion rule" do
        pixel_index = components.index { |c| c["/"] == "/t/*/pixel.gif" && c["exclude"] == true }
        tracking_index = components.index { |c| c["/"] == "/t/*" && !c.key?("exclude") }

        expect(pixel_index).to be_present
        expect(tracking_index).to be_present
        expect(pixel_index).to be < tracking_index
      end
    end

    context "AASA-004: existing /auth/verify component is unchanged" do
      it "preserves the auth/verify component with token query param" do
        auth_component = components.find { |c| c["/"] == "/auth/verify" }
        expect(auth_component).to be_present
        expect(auth_component["?"]).to eq({ "token" => "*" })
      end
    end

    context "AASA-005: AASA does not claim all paths" do
      it "does not include a wildcard-all /* component" do
        wildcard_component = components.find { |c| c["/"] == "/*" }
        expect(wildcard_component).to be_nil
      end

      it "only claims specific path patterns" do
        paths = components.map { |c| c["/"] }
        expect(paths).to all(match(%r{\A/(?:auth/verify|e/|t/)}))
      end
    end

    context "AASA-006: served with correct content type" do
      it "returns application/json content type" do
        get "/.well-known/apple-app-site-association"
        expect(response.content_type).to include("application/json")
      end
    end
  end
end
