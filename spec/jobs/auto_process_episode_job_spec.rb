require "rails_helper"

RSpec.describe AutoProcessEpisodeJob, type: :job do
  include ActiveJob::TestHelper

  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast, audio_url: "https://example.com/audio.mp3") }

  before do
    # Stub external API calls
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
    context "AUTO-001/AUTO-002: auto-processing new episodes" do
      it "transcribes the episode via AssemblyAI" do
        expect(AssemblyAiClient).to receive(:transcribe).with(episode.audio_url)

        described_class.perform_now(episode.id)
      end

      it "summarizes the episode via Claude" do
        expect(ClaudeClient).to receive(:summarize_chunked)

        described_class.perform_now(episode.id)
      end

      it "creates a transcript record for the episode" do
        described_class.perform_now(episode.id)

        expect(episode.reload.transcript).to be_present
      end

      it "creates a summary record for the episode" do
        described_class.perform_now(episode.id)

        expect(episode.reload.summary).to be_present
        expect(episode.summary.sections).to be_present
        expect(episode.summary.quotes).to be_present
      end
    end

    context "AUTO-004: skip already-processed episodes" do
      before do
        create(:transcript, episode: episode)
        create(:summary, episode: episode)
      end

      it "does not re-transcribe the episode" do
        expect(AssemblyAiClient).not_to receive(:transcribe)

        described_class.perform_now(episode.id)
      end

      it "does not re-summarize the episode" do
        expect(ClaudeClient).not_to receive(:summarize_chunked)

        described_class.perform_now(episode.id)
      end
    end

    context "AUTO-004: skip when only transcript exists" do
      before do
        create(:transcript, episode: episode)
      end

      it "does not re-transcribe" do
        expect(AssemblyAiClient).not_to receive(:transcribe)

        described_class.perform_now(episode.id)
      end

      it "still creates the summary" do
        described_class.perform_now(episode.id)

        expect(episode.reload.summary).to be_present
      end
    end

    context "AUTO-005: processing failures are isolated" do
      it "logs error but does not raise for unexpected errors" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(StandardError.new("Network timeout"))

        expect(Rails.logger).to receive(:error).with(/AutoProcessEpisodeJob.*Episode #{episode.id}.*Network timeout/)

        expect {
          described_class.perform_now(episode.id)
        }.not_to raise_error
      end
    end

    context "AUTO-005: retry on rate limit errors" do
      it "enqueues a retry with exponential backoff on ClaudeClient::RateLimitError" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(ClaudeClient::RateLimitError.new("Rate limited"))

        expect {
          described_class.perform_now(episode.id, retry_count: 0)
        }.to have_enqueued_job(AutoProcessEpisodeJob).with(episode.id, retry_count: 1)
      end

      it "enqueues a retry on AssemblyAiClient::Error" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(AssemblyAiClient::Error.new("Service error"))

        expect {
          described_class.perform_now(episode.id, retry_count: 0)
        }.to have_enqueued_job(AutoProcessEpisodeJob).with(episode.id, retry_count: 1)
      end

      it "stops retrying after MAX_RETRIES exceeded" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(ClaudeClient::RateLimitError.new("Rate limited"))

        expect {
          described_class.perform_now(episode.id, retry_count: 5)
        }.not_to have_enqueued_job(AutoProcessEpisodeJob)
      end

      it "logs error when max retries exceeded" do
        allow(AssemblyAiClient).to receive(:transcribe).and_raise(ClaudeClient::RateLimitError.new("Rate limited"))

        expect(Rails.logger).to receive(:error).with(/exceeded.*retries/i)

        described_class.perform_now(episode.id, retry_count: 5)
      end
    end
  end
end
