require "rails_helper"

RSpec.describe "Api::Archive", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in_as(user) }
  let(:podcast) { create(:podcast) }

  describe "GET /api/archive" do
    context "ARC-001: paginated list of archived episodes" do
      it "returns a list of the user's archived episodes" do
        episode = create(:episode, podcast: podcast, title: "Archived Episode", published_at: 1.day.ago)
        user_episode = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)

        get "/api/archive", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)

        ep = parsed["episodes"].first
        expect(ep["id"]).to eq(user_episode.id)
        expect(ep["processing_status"]).to eq("ready")
        expect(ep["location"]).to eq("archive")
        expect(ep["created_at"]).to be_present

        expect(ep["episode"]["id"]).to eq(episode.id)
        expect(ep["episode"]["title"]).to eq("Archived Episode")
        expect(ep["episode"]["published_at"]).to be_present
        expect(ep["episode"]["podcast"]["id"]).to eq(podcast.id)
        expect(ep["episode"]["podcast"]["title"]).to eq(podcast.title)
        expect(ep["episode"]["podcast"]["author"]).to eq(podcast.author)
        expect(ep["episode"]["podcast"]["artwork_url"]).to eq(podcast.artwork_url)
      end

      it "returns summary as null in the list view" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)

        get "/api/archive", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].first["episode"]["summary"]).to be_nil
      end

      it "orders episodes by published_at DESC" do
        old_episode = create(:episode, podcast: podcast, published_at: 3.days.ago)
        new_episode = create(:episode, podcast: podcast, published_at: 1.day.ago)
        create(:user_episode, :in_archive, user: user, episode: old_episode, processing_status: :ready)
        create(:user_episode, :in_archive, user: user, episode: new_episode, processing_status: :ready)

        get "/api/archive", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        ids = parsed["episodes"].map { |e| e["episode"]["id"] }
        expect(ids).to eq([ new_episode.id, old_episode.id ])
      end

      it "returns pagination meta in the response" do
        25.times do |i|
          episode = create(:episode, podcast: podcast, published_at: i.days.ago)
          create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)
        end

        get "/api/archive", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["meta"]).to be_present
        expect(parsed["meta"]["page"]).to eq(1)
        expect(parsed["meta"]["pages"]).to eq(2)
        expect(parsed["meta"]["count"]).to eq(25)
      end

      it "returns the second page when requested" do
        25.times do |i|
          episode = create(:episode, podcast: podcast, published_at: i.days.ago)
          create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)
        end

        get "/api/archive", params: { page: 2 }, headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(5)
        expect(parsed["meta"]["page"]).to eq(2)
      end

      it "returns an empty episodes array for a page beyond the last" do
        episode = create(:episode, podcast: podcast)
        create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)

        get "/api/archive", params: { page: 99 }, headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"]).to eq([])
      end
    end

    context "edge case: empty archive" do
      it "returns empty episodes array with pagination meta" do
        get "/api/archive", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"]).to eq([])
        expect(parsed["meta"]["page"]).to eq(1)
        expect(parsed["meta"]["pages"]).to eq(0)
        expect(parsed["meta"]["count"]).to eq(0)
      end
    end

    context "security: scoping via current_user" do
      it "does not return archived episodes belonging to other users" do
        other_user = create(:user)
        other_episode = create(:episode, podcast: podcast)
        create(:user_episode, :in_archive, user: other_user, episode: other_episode, processing_status: :ready)

        my_episode = create(:episode, podcast: podcast)
        create(:user_episode, :in_archive, user: user, episode: my_episode, processing_status: :ready)

        get "/api/archive", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)
        expect(parsed["episodes"].first["episode"]["id"]).to eq(my_episode.id)
      end

      it "does not return library or trashed episodes" do
        library_episode = create(:episode, podcast: podcast)
        create(:user_episode, :ready, user: user, episode: library_episode)

        trashed_episode = create(:episode, podcast: podcast)
        create(:user_episode, :in_trash, user: user, episode: trashed_episode, processing_status: :ready)

        archived_episode = create(:episode, podcast: podcast)
        create(:user_episode, :in_archive, user: user, episode: archived_episode, processing_status: :ready)

        get "/api/archive", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)
        expect(parsed["episodes"].first["episode"]["id"]).to eq(archived_episode.id)
      end
    end

    context "AUTH-005: requires bearer token" do
      it "returns 401 without a bearer token" do
        get "/api/archive", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end

      it "returns 401 with an invalid bearer token" do
        get "/api/archive", headers: api_headers("invalid-token"), as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end
  end

  describe "POST /api/archive/:id/restore" do
    context "ARC-002: restore an episode from archive" do
      it "restores the episode to the library and returns success" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)

        post "/api/archive/#{user_episode.id}/restore", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Restored to library")

        user_episode.reload
        expect(user_episode.location).to eq("library")
      end

      it "preserves processing_status when restoring — a ready episode stays ready" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)

        post "/api/archive/#{user_episode.id}/restore", headers: api_headers(token), as: :json

        user_episode.reload
        expect(user_episode.processing_status).to eq("ready")
      end

      it "preserves processing_status when restoring — a pending episode stays pending" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :pending)

        post "/api/archive/#{user_episode.id}/restore", headers: api_headers(token), as: :json

        user_episode.reload
        expect(user_episode.processing_status).to eq("pending")
      end

      it "preserves processing_status when restoring — an error episode stays error" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :error)

        post "/api/archive/#{user_episode.id}/restore", headers: api_headers(token), as: :json

        user_episode.reload
        expect(user_episode.processing_status).to eq("error")
      end
    end

    context "ARC-002 edge case: idempotent" do
      it "returns success when restoring an episode already in the library" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        post "/api/archive/#{user_episode.id}/restore", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Restored to library")
      end
    end

    context "ARC-002 edge case: not found" do
      it "returns 404 for a non-existent episode" do
        post "/api/archive/999999/restore", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end

      it "returns 404 for another user's episode" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        other_ue = create(:user_episode, :in_archive, user: other_user, episode: episode, processing_status: :ready)

        post "/api/archive/#{other_ue.id}/restore", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "AUTH-005: requires bearer token" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)

        post "/api/archive/#{user_episode.id}/restore", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end
  end
end
