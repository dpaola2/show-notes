require "rails_helper"

RSpec.describe "Well-Known: Apple App Site Association", type: :request do
  describe "GET /.well-known/apple-app-site-association" do
    context "AUTH-002: AASA file is served with correct content type" do
      it "returns a successful response" do
        get "/.well-known/apple-app-site-association"

        expect(response).to have_http_status(:ok)
      end

      it "serves the file with application/json content type" do
        get "/.well-known/apple-app-site-association"

        expect(response.content_type).to include("application/json")
      end
    end

    context "AUTH-002: AASA file contains correct applinks configuration" do
      it "contains a valid JSON body" do
        get "/.well-known/apple-app-site-association"

        expect { JSON.parse(response.body) }.not_to raise_error
      end

      it "contains the applinks key" do
        get "/.well-known/apple-app-site-association"

        parsed = JSON.parse(response.body)
        expect(parsed).to have_key("applinks")
      end

      it "contains details with the correct app ID format" do
        get "/.well-known/apple-app-site-association"

        parsed = JSON.parse(response.body)
        details = parsed.dig("applinks", "details")
        expect(details).to be_an(Array)
        expect(details.length).to be >= 1

        app_ids = details.map { |d| d["appID"] || d["appIDs"] }.flatten.compact
        # App ID must match the format <TEAM_ID>.com.davepaola.Show-Notes
        expect(app_ids.any? { |id| id.match?(/\A[A-Z0-9]+\.com\.davepaola\.Show-Notes\z/) }).to be true
      end

      it "includes the /auth/verify path pattern for deep link routing" do
        get "/.well-known/apple-app-site-association"

        parsed = JSON.parse(response.body)
        details = parsed.dig("applinks", "details")
        paths = details.flat_map { |d| d["paths"] || [] }
        components = details.flat_map { |d| d["components"] || [] }

        # Either paths or components should reference /auth/verify
        has_verify_path = paths.any? { |p| p.include?("/auth/verify") } ||
                          components.any? { |c| (c["/"] || "").include?("/auth/verify") }
        expect(has_verify_path).to be true
      end
    end

    context "fallback: Universal Link falls through to web verify flow" do
      it "the AASA file only claims specific paths, not the entire domain" do
        get "/.well-known/apple-app-site-association"

        parsed = JSON.parse(response.body)
        details = parsed.dig("applinks", "details")

        # The AASA should NOT claim all paths (e.g., "/*" or "/")
        # It should only claim /auth/verify paths so the web verify flow
        # remains accessible for users without the app installed
        paths = details.flat_map { |d| d["paths"] || [] }
        components = details.flat_map { |d| d["components"] || [] }

        # If using paths format, should not have a catch-all
        unless paths.empty?
          expect(paths).not_to include("*")
          expect(paths).not_to include("/*")
        end
      end
    end
  end
end
