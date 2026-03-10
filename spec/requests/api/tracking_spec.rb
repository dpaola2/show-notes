require "rails_helper"

RSpec.describe "Api::Tracking", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in_as(user) }
  let(:podcast) { create(:podcast) }

  describe "POST /api/tracking/click" do
    context "TC-001: valid token returns episode_id and link_type, fires trigger!" do
      it "returns episode_id and link_type for a summary click event" do
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["episode_id"]).to eq(episode.id)
        expect(parsed["link_type"]).to eq("summary")
      end

      it "returns episode_id and link_type for a listen click event" do
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_listen, user: user, episode: episode)

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["episode_id"]).to eq(episode.id)
        expect(parsed["link_type"]).to eq("listen")
      end

      it "fires trigger! on the email event" do
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        freeze_time do
          post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json

          event.reload
          expect(event.triggered_at).to eq(Time.current)
        end
      end
    end

    context "TC-002: returns 404 for unknown tokens" do
      it "returns 404 when token does not exist" do
        post "/api/tracking/click", params: { token: "nonexistent-token" }, headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "TC-003: returns 401 when no bearer token is provided" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        post "/api/tracking/click", params: { token: event.token }, as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end

      it "returns 401 with an invalid bearer token" do
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers("invalid-token"), as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end

    context "TC-004: returns 404 when token belongs to a different user" do
      it "returns 404 without leaking that the token exists" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: other_user, episode: episode)

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "TC-005: idempotent — calling twice does not error" do
      it "returns success on the second call with the same token" do
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json
        expect(response).to have_http_status(:ok)

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json
        expect(response).to have_http_status(:ok)

        parsed = JSON.parse(response.body)
        expect(parsed["episode_id"]).to eq(episode.id)
        expect(parsed["link_type"]).to eq("summary")
      end

      it "does not update triggered_at on the second call" do
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        travel_to 1.hour.ago do
          post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json
        end
        first_triggered_at = event.reload.triggered_at

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json
        expect(event.reload.triggered_at).to be_within(1.second).of(first_triggered_at)
      end
    end

    context "TC-007: verifies event.user_id == current_user.id before triggering" do
      it "does not trigger an event belonging to another user" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        event = create(:email_event, :click_summary, user: other_user, episode: episode)

        post "/api/tracking/click", params: { token: event.token }, headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        expect(event.reload.triggered_at).to be_nil
      end
    end
  end
end
