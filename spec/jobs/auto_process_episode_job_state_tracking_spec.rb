require "rails_helper"

RSpec.describe AutoProcessEpisodeJob, type: :job do
  include ActiveJob::TestHelper

  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast, audio_url: "https://example.com/audio.mp3") }

  before do
    allow(AssemblyAiClient).to receive(:transcribe).and_return(
      { "segments" => [ { "start" => 0.0, "end" => 10.0, "text" => "Hello world." } ] }
    )
    allow(ClaudeClient).to receive(:summarize_chunked).and_return(
      {
        "sections" => [ { "title" => "Overview", "content" => "A test summary." } ],
        "quotes" => [ { "text" => "Hello world.", "start_time" => 0 } ]
      }
    )
  end

  describe "#perform — episode-level state tracking" do
    context "ERR-001: catches all exceptions and transitions episode to error" do
      it "transitions episode to error on AssemblyAiClient::Error" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("API error"))

        expect {
          described_class.perform_now(episode.id, retry_count: 5)
        }.not_to have_enqueued_job(AutoProcessEpisodeJob)

        episode.reload
        expect(episode.processing_status).to eq("error")
        expect(episode.processing_error).to be_present
        expect(episode.last_error_at).to be_present
      end

      it "transitions episode to error on AssemblyAiClient::RateLimitError after max retries" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(
          AssemblyAiClient::RateLimitError.new("Rate limit exceeded")
        )

        expect {
          described_class.perform_now(episode.id, retry_count: 5)
        }.not_to have_enqueued_job(AutoProcessEpisodeJob)

        episode.reload
        expect(episode.processing_status).to eq("error")
        expect(episode.processing_error).to include("exceeded 5 retries")
      end

      it "transitions episode to error on unexpected exceptions" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(StandardError.new("Something unexpected"))

        described_class.perform_now(episode.id)

        episode.reload
        expect(episode.processing_status).to eq("error")
        expect(episode.processing_error).to include("Something unexpected")
        expect(episode.last_error_at).to be_present
      end

      it "does not raise the error (job isolation)" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(StandardError.new("Network timeout"))

        expect {
          described_class.perform_now(episode.id)
        }.not_to raise_error
      end
    end

    context "ERR-001: state transitions during processing" do
      it "sets episode to transcribing during transcription" do
        allow(AssemblyAiClient).to receive(:transcribe) do
          expect(episode.reload.processing_status).to eq("transcribing")
          { "segments" => [ { "start" => 0.0, "end" => 10.0, "text" => "Hello." } ] }
        end

        described_class.perform_now(episode.id)
      end

      it "sets episode to summarizing during summarization" do
        allow(ClaudeClient).to receive(:summarize_chunked) do
          expect(episode.reload.processing_status).to eq("summarizing")
          {
            "sections" => [ { "title" => "Overview", "content" => "Summary." } ],
            "quotes" => [ { "text" => "Hello.", "start_time" => 0 } ]
          }
        end

        described_class.perform_now(episode.id)
      end

      it "sets episode to ready on successful completion" do
        described_class.perform_now(episode.id)

        episode.reload
        expect(episode.processing_status).to eq("ready")
      end
    end

    context "ERR-003: rate limit errors include actionable guidance" do
      it "includes rate limit context in episode processing_error" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(
          AssemblyAiClient::RateLimitError.new("AssemblyAI rate limit exceeded")
        )

        described_class.perform_now(episode.id, retry_count: 5)

        episode.reload
        expect(episode.processing_error).to include("rate limit")
      end
    end

    context "THR-001/THR-002: concurrency throttling" do
      it "declares limits_concurrency with shared transcription key" do
        expect(described_class).to respond_to(:concurrency_key)
      end
    end

    context "retryable errors schedule retry with exponential backoff" do
      it "enqueues retry on AssemblyAiClient::Error within retry limit" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("Error"))

        expect {
          described_class.perform_now(episode.id, retry_count: 0)
        }.to have_enqueued_job(AutoProcessEpisodeJob).with(episode.id, retry_count: 1)
      end

      it "writes error state during retry" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("Error"))

        described_class.perform_now(episode.id, retry_count: 0)

        episode.reload
        expect(episode.processing_error).to include("Retrying 1/5")
        expect(episode.last_error_at).to be_present
      end

      it "stops retrying after MAX_RETRIES" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("Error"))

        expect {
          described_class.perform_now(episode.id, retry_count: 5)
        }.not_to have_enqueued_job(AutoProcessEpisodeJob)
      end
    end

    context "M6: feed fetch creates episode for multiple subscribers" do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }

      before do
        create(:user_episode, user: user1, episode: episode, location: :inbox)
        create(:user_episode, user: user2, episode: episode, location: :inbox)
      end

      it "transcribes once regardless of subscriber count" do
        expect(AssemblyAiClient).to receive(:transcribe).once

        described_class.perform_now(episode.id)
      end
    end
  end
end
