require "rails_helper"

RSpec.describe "Api::Episodes", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in_as(user) }
  let(:podcast) { create(:podcast) }

  describe "GET /api/episodes/:episode_id/library_entry" do
    context "EP-001: returns user's library entry for the given episode" do
      it "returns the library entry with episode, podcast, and summary data" do
        episode = create(:episode, podcast: podcast, title: "Deep Link Episode", published_at: 1.day.ago)
        summary = create(:summary, episode: episode)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        get "/api/episodes/#{episode.id}/library_entry", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)

        expect(parsed["id"]).to eq(user_episode.id)
        expect(parsed["processing_status"]).to eq("ready")
        expect(parsed["location"]).to eq("library")
        expect(parsed["created_at"]).to be_present

        ep = parsed["episode"]
        expect(ep["id"]).to eq(episode.id)
        expect(ep["title"]).to eq("Deep Link Episode")
        expect(ep["published_at"]).to be_present
        expect(ep["podcast"]["id"]).to eq(podcast.id)
        expect(ep["podcast"]["title"]).to eq(podcast.title)
        expect(ep["podcast"]["author"]).to eq(podcast.author)
        expect(ep["podcast"]["artwork_url"]).to eq(podcast.artwork_url)

        expect(ep["summary"]["sections"]).to be_an(Array)
        expect(ep["summary"]["sections"].length).to eq(3)
        expect(ep["summary"]["quotes"]).to be_an(Array)
        expect(ep["summary"]["quotes"].length).to eq(2)
      end

      it "returns summary as null when the episode has no summary" do
        episode = create(:episode, podcast: podcast)
        create(:user_episode, :ready, user: user, episode: episode)

        get "/api/episodes/#{episode.id}/library_entry", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["episode"]["summary"]).to be_nil
      end
    end

    context "EP-002: returns 404 when episode does not exist" do
      it "returns 404 for a non-existent episode ID" do
        get "/api/episodes/999999/library_entry", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "EP-003: returns 404 when episode exists but user has no library entry" do
      it "returns 404 without leaking that the episode exists" do
        episode = create(:episode, podcast: podcast)
        # Episode exists but user has no user_episode for it

        get "/api/episodes/#{episode.id}/library_entry", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "EP-004: returns 401 when no bearer token is provided" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)

        get "/api/episodes/#{episode.id}/library_entry", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end

      it "returns 401 with an invalid bearer token" do
        episode = create(:episode, podcast: podcast)

        get "/api/episodes/#{episode.id}/library_entry", headers: api_headers("invalid-token"), as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end

    context "EP-005: response uses same JSON shape as GET /api/library/:id" do
      it "matches the library show endpoint response structure" do
        episode = create(:episode, podcast: podcast, published_at: 1.day.ago)
        summary = create(:summary, episode: episode)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        # Get library entry via episode ID
        get "/api/episodes/#{episode.id}/library_entry", headers: api_headers(token), as: :json
        episode_lookup_response = JSON.parse(response.body)

        # Get the same entry via library show
        get "/api/library/#{user_episode.id}", headers: api_headers(token), as: :json
        library_show_response = JSON.parse(response.body)

        # Both responses should have identical structure
        expect(episode_lookup_response.keys.sort).to eq(library_show_response.keys.sort)
        expect(episode_lookup_response["id"]).to eq(library_show_response["id"])
        expect(episode_lookup_response["episode"].keys.sort).to eq(library_show_response["episode"].keys.sort)
      end
    end

    context "TC-006: query scoped to current_user.user_episodes" do
      it "cannot access another user's library entry" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        create(:user_episode, :ready, user: other_user, episode: episode)

        get "/api/episodes/#{episode.id}/library_entry", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end
  end
end
