require "rails_helper"

RSpec.describe "Api::Episodes routing", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in_as(user) }

  describe "ROUTE-001: GET /api/episodes/:episode_id/library_entry" do
    it "routes to Api::EpisodesController#library_entry" do
      expect(get: "/api/episodes/42/library_entry").to route_to(
        controller: "api/episodes",
        action: "library_entry",
        episode_id: "42",
        format: :json
      )
    end
  end

  describe "ROUTE-002: POST /api/tracking/click" do
    it "routes to Api::TrackingController#click" do
      expect(post: "/api/tracking/click").to route_to(
        controller: "api/tracking",
        action: "click",
        format: :json
      )
    end
  end
end
