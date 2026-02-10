require "rails_helper"

RSpec.describe "Library Retry", type: :request do
  include ActiveJob::TestHelper

  let!(:user) { create(:user) }
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast) }

  before do
    sign_in_as(user)
  end

  describe "POST /library/:id/retry_processing" do
    context "LIB-001: retry from library" do
      let!(:user_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :library,
          processing_status: :error,
          processing_error: "AssemblyAI rate limit exceeded",
          retry_count: 3,
          next_retry_at: 5.minutes.from_now
        )
      end

      it "resets processing_status to pending" do
        post retry_processing_library_path(user_episode)

        user_episode.reload
        expect(user_episode.processing_status).to eq("pending")
      end

      it "clears error fields" do
        post retry_processing_library_path(user_episode)

        user_episode.reload
        expect(user_episode.processing_error).to be_nil
        expect(user_episode.retry_count).to eq(0)
        expect(user_episode.next_retry_at).to be_nil
      end

      it "enqueues ProcessEpisodeJob" do
        expect {
          post retry_processing_library_path(user_episode)
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)
      end

      it "redirects back with notice" do
        post retry_processing_library_path(user_episode)

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response.body).to include("Retry")
      end
    end

    context "LIB-001: library index shows error message and retry button" do
      let!(:errored_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :library,
          processing_status: :error,
          processing_error: "AssemblyAI rate limit exceeded"
        )
      end

      it "displays error message on library index" do
        get library_index_path

        expect(response.body).to include("AssemblyAI rate limit exceeded")
      end

      it "shows retry button on library index for error episodes" do
        get library_index_path

        expect(response.body).to include("Retry")
      end
    end

    context "LIB-002: failure count visible alongside error message" do
      let!(:multi_retry_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :library,
          processing_status: :error,
          processing_error: "Rate limited (exceeded 5 retries)",
          retry_count: 5
        )
      end

      it "displays retry count in error state" do
        get library_index_path

        # The retry count should be visible — exact format depends on implementation
        expect(response.body).to include("5")
      end
    end

    context "library show page retry button uses retry_processing" do
      let!(:errored_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :library,
          processing_status: :error,
          processing_error: "Transcription failed"
        )
      end

      it "shows retry button on show page wired to retry_processing" do
        get library_path(errored_episode)

        expect(response.body).to include("retry_processing")
      end
    end

    context "existing regenerate action still works for ready episodes" do
      let!(:ready_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :library,
          processing_status: :ready
        )
      end

      before do
        create(:transcript, episode: episode)
        create(:summary, episode: episode)
      end

      it "regenerate action is still available for ready episodes" do
        expect {
          post regenerate_library_path(ready_episode)
        }.to have_enqueued_job(ProcessEpisodeJob)

        ready_episode.reload
        expect(ready_episode.processing_status).to eq("summarizing")
      end
    end

    context "security: scoping to current user" do
      let(:other_user) { create(:user) }
      let!(:other_user_episode) do
        create(:user_episode,
          user: other_user,
          episode: episode,
          location: :library,
          processing_status: :error,
          processing_error: "Error"
        )
      end

      it "raises RecordNotFound for another user's episode" do
        expect {
          post retry_processing_library_path(other_user_episode)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "M6: multiple episodes fail simultaneously" do
      let(:episode2) { create(:episode, podcast: podcast) }

      let!(:error1) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :library,
          processing_status: :error,
          processing_error: "Rate limit exceeded"
        )
      end

      let!(:error2) do
        create(:user_episode,
          user: user,
          episode: episode2,
          location: :library,
          processing_status: :error,
          processing_error: "Network timeout"
        )
      end

      it "shows individual error states for all failed episodes" do
        get library_index_path

        expect(response.body).to include("Rate limit exceeded")
        expect(response.body).to include("Network timeout")
      end
    end

    context "M6: error state styling is visually distinct" do
      let!(:errored_episode) do
        create(:user_episode,
          user: user,
          episode: episode,
          location: :library,
          processing_status: :error,
          processing_error: "Failed"
        )
      end

      it "uses red/warning styling for error state" do
        get library_index_path

        # Error state should use red styling (text-red-600 per architecture proposal)
        expect(response.body).to include("text-red")
      end
    end
  end
end
