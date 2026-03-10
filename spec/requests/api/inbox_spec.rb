require "rails_helper"

RSpec.describe "Api::Inbox", type: :request do
  let(:user) { create(:user) }
  let(:token) { api_sign_in_as(user) }
  let(:podcast) { create(:podcast) }

  describe "GET /api/inbox" do
    context "happy path: returns inbox episodes sorted by published_at DESC" do
      it "returns a list of the user's inbox episodes" do
        episode = create(:episode, podcast: podcast, title: "Test Episode", published_at: 1.day.ago)
        user_episode = create(:user_episode, user: user, episode: episode)

        get "/api/inbox", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)

        ep = parsed["episodes"].first
        expect(ep["id"]).to eq(user_episode.id)
        expect(ep["processing_status"]).to eq("pending")
        expect(ep["location"]).to eq("inbox")
        expect(ep["created_at"]).to be_present

        expect(ep["episode"]["id"]).to eq(episode.id)
        expect(ep["episode"]["title"]).to eq("Test Episode")
        expect(ep["episode"]["published_at"]).to be_present
        expect(ep["episode"]["podcast"]["id"]).to eq(podcast.id)
        expect(ep["episode"]["podcast"]["title"]).to eq(podcast.title)
      end

      it "orders episodes by published_at DESC" do
        old_episode = create(:episode, podcast: podcast, published_at: 3.days.ago)
        new_episode = create(:episode, podcast: podcast, published_at: 1.day.ago)
        create(:user_episode, user: user, episode: old_episode)
        create(:user_episode, user: user, episode: new_episode)

        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        ids = parsed["episodes"].map { |e| e["episode"]["id"] }
        expect(ids).to eq([new_episode.id, old_episode.id])
      end

      it "includes processing_error field" do
        episode = create(:episode, podcast: podcast)
        create(:user_episode, user: user, episode: episode, processing_status: :error, processing_error: "Download failed")

        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].first["processing_error"]).to eq("Download failed")
      end

      it "includes duration_seconds in the episode block" do
        episode = create(:episode, podcast: podcast, duration_seconds: 3600)
        create(:user_episode, user: user, episode: episode)

        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].first["episode"]["duration_seconds"]).to eq(3600)
      end
    end

    context "pagination" do
      before do
        25.times do |i|
          episode = create(:episode, podcast: podcast, published_at: i.days.ago)
          create(:user_episode, user: user, episode: episode)
        end
      end

      it "returns pagination meta in the response" do
        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["meta"]).to be_present
        expect(parsed["meta"]["page"]).to eq(1)
        expect(parsed["meta"]["pages"]).to eq(2)
        expect(parsed["meta"]["count"]).to eq(25)
      end

      it "returns 20 episodes per page by default" do
        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(20)
      end

      it "returns the second page when requested" do
        get "/api/inbox", params: { page: 2 }, headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(5)
        expect(parsed["meta"]["page"]).to eq(2)
      end

      it "returns an empty episodes array for a page beyond the last" do
        get "/api/inbox", params: { page: 99 }, headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"]).to eq([])
      end
    end

    context "empty inbox" do
      it "returns empty episodes array with pagination meta" do
        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"]).to eq([])
        expect(parsed["meta"]["page"]).to eq(1)
        expect(parsed["meta"]["pages"]).to eq(0)
        expect(parsed["meta"]["count"]).to eq(0)
      end
    end

    context "user isolation" do
      it "does not return episodes belonging to other users" do
        other_user = create(:user)
        other_episode = create(:episode, podcast: podcast)
        create(:user_episode, user: other_user, episode: other_episode)

        my_episode = create(:episode, podcast: podcast)
        create(:user_episode, user: user, episode: my_episode)

        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)
        expect(parsed["episodes"].first["episode"]["id"]).to eq(my_episode.id)
      end

      it "does not return library, archived, or trashed episodes" do
        library_ep = create(:episode, podcast: podcast)
        create(:user_episode, :in_library, user: user, episode: library_ep)

        archived_ep = create(:episode, podcast: podcast)
        create(:user_episode, :in_archive, user: user, episode: archived_ep)

        trashed_ep = create(:episode, podcast: podcast)
        create(:user_episode, :in_trash, user: user, episode: trashed_ep)

        inbox_ep = create(:episode, podcast: podcast)
        create(:user_episode, user: user, episode: inbox_ep)

        get "/api/inbox", headers: api_headers(token), as: :json

        parsed = JSON.parse(response.body)
        expect(parsed["episodes"].length).to eq(1)
        expect(parsed["episodes"].first["episode"]["id"]).to eq(inbox_ep.id)
      end
    end

    context "requires bearer token" do
      it "returns 401 without a bearer token" do
        get "/api/inbox", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end

      it "returns 401 with an invalid bearer token" do
        get "/api/inbox", headers: api_headers("invalid-token"), as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end
  end

  describe "POST /api/inbox/:id/add_to_library" do
    context "happy path" do
      it "moves the episode to library and enqueues ProcessEpisodeJob" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, user: user, episode: episode)

        expect {
          post "/api/inbox/#{user_episode.id}/add_to_library", headers: api_headers(token), as: :json
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Added to library")

        user_episode.reload
        expect(user_episode.location).to eq("library")
      end
    end

    context "not found" do
      it "returns 404 for a non-inbox episode" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_library, user: user, episode: episode)

        post "/api/inbox/#{user_episode.id}/add_to_library", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end

      it "returns 404 for another user's episode" do
        other_user = create(:user)
        episode = create(:episode, podcast: podcast)
        other_ue = create(:user_episode, user: other_user, episode: episode)

        post "/api/inbox/#{other_ue.id}/add_to_library", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "requires bearer token" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, user: user, episode: episode)

        post "/api/inbox/#{user_episode.id}/add_to_library", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/inbox/:id/skip" do
    context "happy path" do
      it "moves the episode to trash and sets trashed_at" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, user: user, episode: episode)

        post "/api/inbox/#{user_episode.id}/skip", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Skipped")

        user_episode.reload
        expect(user_episode.location).to eq("trash")
        expect(user_episode.trashed_at).to be_present
      end
    end

    context "not found" do
      it "returns 404 for a non-inbox episode" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :in_library, user: user, episode: episode)

        post "/api/inbox/#{user_episode.id}/skip", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "requires bearer token" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, user: user, episode: episode)

        post "/api/inbox/#{user_episode.id}/skip", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/inbox/:id/retry_processing" do
    context "happy path" do
      it "resets error state and enqueues ProcessEpisodeJob" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, user: user, episode: episode, processing_status: :error, processing_error: "Download failed")

        expect {
          post "/api/inbox/#{user_episode.id}/retry_processing", headers: api_headers(token), as: :json
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Retrying")

        user_episode.reload
        expect(user_episode.processing_status).to eq("pending")
        expect(user_episode.processing_error).to be_nil
      end
    end

    context "episode not in error state" do
      it "returns 422 for a non-error episode" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, user: user, episode: episode)

        post "/api/inbox/#{user_episode.id}/retry_processing", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Episode is not in error state")
      end
    end

    context "not found" do
      it "returns 404 for a non-inbox episode" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, :with_error, user: user, episode: episode)

        post "/api/inbox/#{user_episode.id}/retry_processing", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Not found")
      end
    end

    context "requires bearer token" do
      it "returns 401 without a bearer token" do
        episode = create(:episode, podcast: podcast)
        user_episode = create(:user_episode, user: user, episode: episode, processing_status: :error)

        post "/api/inbox/#{user_episode.id}/retry_processing", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/inbox/clear" do
    context "happy path" do
      it "trashes all inbox episodes and returns count" do
        3.times do
          episode = create(:episode, podcast: podcast)
          create(:user_episode, user: user, episode: episode)
        end

        delete "/api/inbox/clear", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Cleared 3 episodes")

        expect(user.user_episodes.in_inbox.count).to eq(0)
        expect(user.user_episodes.in_trash.count).to eq(3)
        user.user_episodes.in_trash.each do |ue|
          expect(ue.trashed_at).to be_present
        end
      end
    end

    context "empty inbox" do
      it "returns 0 count" do
        delete "/api/inbox/clear", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Cleared 0 episodes")
      end
    end

    context "requires bearer token" do
      it "returns 401 without a bearer token" do
        delete "/api/inbox/clear", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
