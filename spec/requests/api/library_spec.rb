require "rails_helper"

RSpec.describe "Api::Library", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in_as(user) }
  let(:podcast) { create(:podcast) }

  describe "GET /api/library" do
    context "LIB-001: paginated list of library episodes" do
      it "returns a list of the user's library episodes" do
        episode = create(:episode, podcast: podcast, title: "Test Episode", published_at: 1.day.ago)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        get "/api/library", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)

        ep = parsed["episodes"].first
        expect(ep["id"]).to eq(user_episode.id)
        expect(ep["processing_status"]).to eq("ready")
        expect(ep["location"]).to eq("library")
        expect(ep["created_at"]).to be_present

        expect(ep["episode"]["id"]).to eq(episode.id)
        expect(ep["episode"]["title"]).to eq("Test Episode")
        expect(ep["episode"]["published_at"]).to be_present
        expect(ep["episode"]["podcast"]["id"]).to eq(podcast.id)
        expect(ep["episode"]["podcast"]["title"]).to eq(podcast.title)
        expect(ep["episode"]["podcast"]["author"]).to eq(podcast.author)
        expect(ep["episode"]["podcast"]["artwork_url"]).to eq(podcast.artwork_url)
      end

      it "returns summary as null in the list view" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        create(:user_episode, :ready, user: user, episode: episode)

        get "/api/library", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].first["episode"]["summary"]).to be_nil
      end

      it "orders episodes by published_at DESC by default" do
        old_episode = create(:episode, podcast: podcast, published_at: 3.days.ago)
        new_episode = create(:episode, podcast: podcast, published_at: 1.day.ago)
        create(:user_episode, :ready, user: user, episode: old_episode)
        create(:user_episode, :ready, user: user, episode: new_episode)

        get "/api/library", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        ids = parsed["episodes"].map { |e| e["episode"]["id"] }
        expect(ids).to eq([ new_episode.id, old_episode.id ])
      end

      it "orders episodes by published_at ASC when sort=oldest" do
        old_episode = create(:episode, podcast: podcast, published_at: 3.days.ago)
        new_episode = create(:episode, podcast: podcast, published_at: 1.day.ago)
        create(:user_episode, :ready, user: user, episode: old_episode)
        create(:user_episode, :ready, user: user, episode: new_episode)

        get "/api/library", params: { sort: "oldest" }, headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        ids = parsed["episodes"].map { |e| e["episode"]["id"] }
        expect(ids).to eq([ old_episode.id, new_episode.id ])
      end
    end

    context "LIB-002: page-based pagination with Pagy" do
      before do
        25.times do |i|
          episode = create(:episode, podcast: podcast, published_at: i.days.ago)
          create(:user_episode, :ready, user: user, episode: episode)
        end
      end

      it "returns pagination meta in the response" do
        get "/api/library", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["meta"]).to be_present
        expect(parsed["meta"]["page"]).to eq(1)
        expect(parsed["meta"]["pages"]).to eq(2)
        expect(parsed["meta"]["count"]).to eq(25)
      end

      it "returns 20 episodes per page by default" do
        get "/api/library", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(20)
      end

      it "returns the second page when requested" do
        get "/api/library", params: { page: 2 }, headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(5)
        expect(parsed["meta"]["page"]).to eq(2)
      end

      it "returns an empty episodes array for a page beyond the last" do
        get "/api/library", params: { page: 99 }, headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"]).to eq([])
      end
    end

    context "edge case: empty library" do
      it "returns empty episodes array with pagination meta" do
        get "/api/library", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"]).to eq([])
        expect(parsed["meta"]["page"]).to eq(1)
        expect(parsed["meta"]["pages"]).to eq(0)
        expect(parsed["meta"]["count"]).to eq(0)
      end
    end

    context "security: scoping via current_user" do
      it "does not return episodes belonging to other users" do
        other_user = create(:user)
        other_episode = create(:episode, podcast: podcast)
        create(:user_episode, :ready, user: other_user, episode: other_episode)

        my_episode = create(:episode, podcast: podcast)
        create(:user_episode, :ready, user: user, episode: my_episode)

        get "/api/library", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)
        expect(parsed["episodes"].first["episode"]["id"]).to eq(my_episode.id)
      end

      it "does not return archived or trashed episodes" do
        archived_episode = create(:episode, podcast: podcast)
        create(:user_episode, :in_archive, user: user, episode: archived_episode, processing_status: :ready)

        trashed_episode = create(:episode, podcast: podcast)
        create(:user_episode, :in_trash, user: user, episode: trashed_episode, processing_status: :ready)

        library_episode = create(:episode, podcast: podcast)
        create(:user_episode, :ready, user: user, episode: library_episode)

        get "/api/library", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)
        expect(parsed["episodes"].first["episode"]["id"]).to eq(library_episode.id)
      end
    end

    context "AUTH-005: requires bearer token" do
      it "returns 401 without a bearer token" do
        get "/api/library", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end

      it "returns 401 with an invalid bearer token" do
        get "/api/library", headers: api_headers("invalid-token"), as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end
  end

  describe "GET /api/library/:id" do
    context "LIB-003: full episode detail with summary" do
      it "returns the episode detail with nested summary" do
        episode = create(:episode, podcast: podcast, title: "Detail Episode", published_at: 1.day.ago)
        summary = create(:summary, episode: episode)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        get "/api/library/#{user_episode.id}", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)

        expect(parsed["id"]).to eq(user_episode.id)
        expect(parsed["processing_status"]).to eq("ready")
        expect(parsed["location"]).to eq("library")
        expect(parsed["created_at"]).to be_present

        ep = parsed["episode"]
        expect(ep["id"]).to eq(episode.id)
        expect(ep["title"]).to eq("Detail Episode")
        expect(ep["published_at"]).to be_present
        expect(ep["podcast"]["id"]).to eq(podcast.id)
        expect(ep["podcast"]["title"]).to eq(podcast.title)
        expect(ep["podcast"]["author"]).to eq(podcast.author)
        expect(ep["podcast"]["artwork_url"]).to eq(podcast.artwork_url)

        # Summary sections
        expect(ep["summary"]["sections"]).to be_an(Array)
        expect(ep["summary"]["sections"].length).to eq(3)
        section = ep["summary"]["sections"].first
        expect(section["title"]).to eq("Introduction")
        expect(section["content"]).to be_present

        # Summary quotes
        expect(ep["summary"]["quotes"]).to be_an(Array)
        expect(ep["summary"]["quotes"].length).to eq(2)
        quote = ep["summary"]["quotes"].first
        expect(quote["text"]).to be_present
      end

      it "does not include start_time and end_time in summary sections" do
        episode = create(:episode, podcast: podcast)
        create(:summary, episode: episode)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        get "/api/library/#{user_episode.id}", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        section = parsed["episode"]["summary"]["sections"].first
        expect(section).not_to have_key("start_time")
        expect(section).not_to have_key("end_time")

        quote = parsed["episode"]["summary"]["quotes"].first
        expect(quote).not_to have_key("start_time")
        expect(quote).not_to have_key("end_time")
      end
    end

    context "LIB-003 edge case: episode not found" do
      it "returns 404 for a non-existent episode" do
        get "/api/library/999999", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end

      it "returns 404 for another user's episode" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        other_ue = create(:user_episode, :ready, user: other_user, episode: episode)

        get "/api/library/#{other_ue.id}", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "LIB-003 edge case: no summary yet" do
      it "returns summary as null when the episode has no summary" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        get "/api/library/#{user_episode.id}", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["episode"]["summary"]).to be_nil
      end
    end

    context "AUTH-005: requires bearer token" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        get "/api/library/#{user_episode.id}", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end
  end

  describe "POST /api/library/:id/archive" do
    context "LIB-004: archive an episode" do
      it "moves the episode to archive and returns success" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        post "/api/library/#{user_episode.id}/archive", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Archived")

        user_episode.reload
        expect(user_episode.location).to eq("archive")
      end
    end

    context "LIB-004 edge case: idempotent" do
      it "returns success when archiving an already-archived episode" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_archive, user: user, episode: episode, processing_status: :ready)

        post "/api/library/#{user_episode.id}/archive", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Archived")
      end
    end

    context "LIB-004 edge case: not found" do
      it "returns 404 for a non-existent episode" do
        post "/api/library/999999/archive", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end

      it "returns 404 for another user's episode" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        other_ue = create(:user_episode, :ready, user: other_user, episode: episode)

        post "/api/library/#{other_ue.id}/archive", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "AUTH-005: requires bearer token" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :ready, user: user, episode: episode)

        post "/api/library/#{user_episode.id}/archive", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end
  end

  describe "API-002: Jbuilder JSON serialization" do
    it "returns properly structured JSON with snake_case keys" do
      episode = create(:episode, podcast: podcast, published_at: 1.day.ago)
      create(:user_episode, :ready, user: user, episode: episode)

      get "/api/library", headers: api_headers(token), as: :json

      parsed = JSON.parse(response.body)
      ep = parsed["episodes"].first

      # Verify snake_case key convention
      expect(ep).to have_key("processing_status")
      expect(ep).to have_key("created_at")
      expect(ep["episode"]).to have_key("published_at")
      expect(ep["episode"]["podcast"]).to have_key("artwork_url")
    end
  end
end
