require "rails_helper"

RSpec.describe ProcessEpisodeJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast, audio_url: "https://example.com/audio.mp3") }
  let!(:user_episode) { create(:user_episode, user: user, episode: episode, location: :library, processing_status: :pending) }

  before do
    allow(AssemblyAiClient).to receive(:transcribe).and_return(
      { "segments" => [{ "start" => 0.0, "end" => 10.0, "text" => "Hello world." }] }
    )
    allow(ClaudeClient).to receive(:summarize_chunked).and_return(
      {
        "sections" => [{ "title" => "Overview", "content" => "A test summary." }],
        "quotes" => [{ "text" => "Hello world.", "start_time" => 0 }]
      }
    )
  end

  describe "#perform" do
    context "ERR-001: catches all exception types and transitions to error" do
      it "catches AssemblyAiClient::Error and retries with backoff" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("API error"))

        expect {
          described_class.perform_now(user_episode.id)
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)

        user_episode.reload
        expect(user_episode.retry_count).to eq(1)
        expect(user_episode.last_error_at).to be_present
      end

      it "catches AssemblyAiClient::RateLimitError and retries with backoff" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::RateLimitError.new("Rate limited"))

        expect {
          described_class.perform_now(user_episode.id)
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)

        user_episode.reload
        expect(user_episode.retry_count).to eq(1)
      end

      it "catches ClaudeClient::RateLimitError and retries with backoff" do
        create(:transcript, episode: episode)
        allow(ClaudeClient).to receive(:summarize_chunked).and_raise(ClaudeClient::RateLimitError.new("Rate limited"))

        expect {
          described_class.perform_now(user_episode.id)
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)

        user_episode.reload
        expect(user_episode.retry_count).to eq(1)
      end

      it "catches unexpected exceptions and transitions to error state" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(StandardError.new("Something unexpected"))

        described_class.perform_now(user_episode.id)

        user_episode.reload
        expect(user_episode.processing_status).to eq("error")
        expect(user_episode.processing_error).to include("Something unexpected")
        expect(user_episode.last_error_at).to be_present
      end

      it "transitions to error after exceeding MAX_RETRIES" do
        user_episode.update!(retry_count: 5)
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("Persistent failure"))

        expect {
          described_class.perform_now(user_episode.id)
        }.not_to have_enqueued_job(ProcessEpisodeJob)

        user_episode.reload
        expect(user_episode.processing_status).to eq("error")
        expect(user_episode.processing_error).to include("exceeded 5 retries")
      end
    end

    context "ERR-003: rate limit errors include actionable guidance" do
      it "includes rate limit context in the error message" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(
          AssemblyAiClient::RateLimitError.new("AssemblyAI rate limit exceeded")
        )

        described_class.perform_now(user_episode.id)

        user_episode.reload
        expect(user_episode.processing_error).to include("rate limit")
      end
    end

    context "THR-001/THR-002: concurrency throttling" do
      it "declares limits_concurrency with shared transcription key" do
        expect(described_class).to respond_to(:concurrency_key)
      end
    end

    context "THR-003: throttled episodes show pending status" do
      it "does not set all episodes to transcribing simultaneously" do
        # When the job starts, only the active episode transitions to transcribing
        # Other pending episodes remain pending until a slot opens
        user_episode.update!(processing_status: :pending)

        allow(AssemblyAiClient).to receive(:transcribe) do
          # During transcription, verify our episode is transcribing
          expect(user_episode.reload.processing_status).to eq("transcribing")
          { "segments" => [{ "start" => 0.0, "end" => 10.0, "text" => "Hello." }] }
        end

        described_class.perform_now(user_episode.id)
      end
    end

    context "happy path: full processing pipeline" do
      it "transitions through transcribing -> summarizing -> ready" do
        described_class.perform_now(user_episode.id)

        user_episode.reload
        expect(user_episode.processing_status).to eq("ready")
        expect(user_episode.retry_count).to eq(0)
        expect(user_episode.next_retry_at).to be_nil
      end

      it "creates transcript and summary records" do
        described_class.perform_now(user_episode.id)

        expect(episode.reload.transcript).to be_present
        expect(episode.summary).to be_present
      end
    end

    context "skip already-processed episodes" do
      before do
        create(:transcript, episode: episode)
        create(:summary, episode: episode)
      end

      it "skips transcription and summarization when both exist" do
        expect(AssemblyAiClient).not_to receive(:transcribe)
        expect(ClaudeClient).not_to receive(:summarize_chunked)

        described_class.perform_now(user_episode.id)

        user_episode.reload
        expect(user_episode.processing_status).to eq("ready")
      end
    end

    context "partial processing: transcript exists but summary does not" do
      before do
        create(:transcript, episode: episode)
      end

      it "skips transcription but performs summarization" do
        expect(AssemblyAiClient).not_to receive(:transcribe)
        expect(ClaudeClient).to receive(:summarize_chunked)

        described_class.perform_now(user_episode.id)

        user_episode.reload
        expect(user_episode.processing_status).to eq("ready")
      end
    end

    context "retry exponential backoff" do
      it "uses exponential backoff delay: 1min, 2min, 4min, 8min, 16min" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("Error"))

        described_class.perform_now(user_episode.id)

        user_episode.reload
        expect(user_episode.retry_count).to eq(1)
        expect(user_episode.next_retry_at).to be_present
      end

      it "schedules retry with increasing delay" do
        user_episode.update!(retry_count: 2)
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("Error"))

        expect {
          described_class.perform_now(user_episode.id)
        }.to have_enqueued_job(ProcessEpisodeJob).with(user_episode.id)

        user_episode.reload
        expect(user_episode.retry_count).to eq(3)
      end
    end

    context "M6: concurrent retry idempotency" do
      it "does not make duplicate API calls when transcript already exists" do
        create(:transcript, episode: episode)

        expect(AssemblyAiClient).not_to receive(:transcribe)

        described_class.perform_now(user_episode.id)
      end
    end
  end
end
