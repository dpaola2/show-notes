require "rails_helper"

RSpec.describe "Inbox Retry", type: :request do
  let!(:user) { create(:user) }
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast) }

  before do
    sign_in_as(user)
  end

  describe "POST /inbox/retry_processing" do
    context "INB-003: clicking Retry resets state and enqueues job" do
      let!(:user_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :inbox,
          processing_status: :error,
          processing_error: "AssemblyAI rate limit exceeded",
          retry_count: 3,
          next_retry_at: 5.minutes.from_now
        )
      end

      it "resets processing_status to pending" do
        post retry_processing_inbox_index_path, params: { id: user_episode.id }

        user_episode.reload
        expect(user_episode.processing_status).to eq("pending")
      end

      it "clears error fields" do
        post retry_processing_inbox_index_path, params: { id: user_episode.id }

        user_episode.reload
        expect(user_episode.processing_error).to be_nil
        expect(user_episode.retry_count).to eq(0)
        expect(user_episode.next_retry_at).to be_nil
      end

      it "enqueues ProcessEpisodeJob" do
        expect {
          post retry_processing_inbox_index_path, params: { id: user_episode.id }
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)
      end

      it "redirects to inbox with notice" do
        post retry_processing_inbox_index_path, params: { id: user_episode.id }

        expect(response).to redirect_to(inbox_index_path)
        follow_redirect!
        expect(response.body).to include("Retry")
      end
    end

    context "INB-002: error state displays in inbox" do
      let!(:error_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :inbox,
          processing_status: :error,
          processing_error: "Network timeout"
        )
      end

      it "shows error reason on inbox page" do
        get inbox_index_path

        expect(response.body).to include("Network timeout")
      end

      it "shows retry button for errored episodes" do
        get inbox_index_path

        expect(response.body).to include("Retry")
      end
    end

    context "INB-001: inbox displays processing status" do
      it "shows transcribing status" do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :inbox,
          processing_status: :transcribing
        )

        get inbox_index_path

        expect(response.body).to include("Transcribing")
      end

      it "shows summarizing status" do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :inbox,
          processing_status: :summarizing
        )

        get inbox_index_path

        expect(response.body).to include("summary")
      end

      it "shows ready status" do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :inbox,
          processing_status: :ready
        )

        get inbox_index_path

        expect(response.body).to include("Ready")
      end
    end

    context "security: scoping to current user" do
      let(:other_user) { create(:user) }
      let!(:other_user_episode) do
        create(:user_episode,
          user: other_user,
          episode: episode,
          location: :inbox,
          processing_status: :error,
          processing_error: "Error"
        )
      end

      it "raises RecordNotFound for another user's episode" do
        expect {
          post retry_processing_inbox_index_path, params: { id: other_user_episode.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "INB-004: Add to Library works on errored episodes" do
      let!(:errored_inbox_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :inbox,
          processing_status: :error,
          processing_error: "Rate limit exceeded"
        )
      end

      it "allows add_to_library on errored episodes" do
        post add_to_library_inbox_index_path, params: { id: errored_inbox_episode.id }

        errored_inbox_episode.reload
        expect(errored_inbox_episode.location).to eq("library")
      end
    end
  end
end
