require "rails_helper"

RSpec.describe "Api::Me", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in_as(user) }

  describe "GET /api/me" do
    it "returns the authenticated user's id and email" do
      get "/api/me", headers: api_headers(token), as: :json

      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)
      expect(parsed["id"]).to eq(user.id)
      expect(parsed["email"]).to eq(user.email)
    end

    it "returns 401 without a bearer token" do
      get "/api/me", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
