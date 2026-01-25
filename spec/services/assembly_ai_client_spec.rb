require "rails_helper"

RSpec.describe AssemblyAiClient do
  describe "#transcribe" do
    let(:client) { described_class.new(api_key: "test-api-key") }
    let(:mock_assemblyai_client) { instance_double(AssemblyAI::Client) }
    let(:mock_transcripts) { double("transcripts") }
    let(:audio_url) { "https://example.com/podcast.mp3" }

    let(:mock_transcript) do
      instance_double(
        AssemblyAI::Transcripts::Transcript,
        status: AssemblyAI::Transcripts::TranscriptStatus::COMPLETED,
        text: "Welcome to the show. Today we're discussing important topics.",
        words: [
          double(text: "Welcome", start: 0, end_: 500, confidence: 0.99, speaker: "A"),
          double(text: "to", start: 500, end_: 600, confidence: 0.98, speaker: "A")
        ],
        utterances: [
          double(text: "Welcome to the show.", start: 0, end_: 2500, confidence: 0.95, speaker: "A")
        ],
        audio_duration: 6000,
        confidence: 0.97,
        error: nil
      )
    end

    before do
      allow(AssemblyAI::Client).to receive(:new).and_return(mock_assemblyai_client)
      allow(mock_assemblyai_client).to receive(:transcripts).and_return(mock_transcripts)
    end

    it "calls AssemblyAI API with audio URL" do
      allow(mock_transcripts).to receive(:transcribe).and_return(mock_transcript)

      client.transcribe(audio_url)

      expect(mock_transcripts).to have_received(:transcribe).with(
        audio_url: audio_url,
        speaker_labels: true
      )
    end

    it "returns formatted transcription data" do
      allow(mock_transcripts).to receive(:transcribe).and_return(mock_transcript)

      result = client.transcribe(audio_url)

      expect(result["text"]).to eq("Welcome to the show. Today we're discussing important topics.")
      expect(result["words"].length).to eq(2)
      expect(result["words"].first["text"]).to eq("Welcome")
      expect(result["utterances"].length).to eq(1)
      expect(result["audio_duration"]).to eq(6000)
      expect(result["confidence"]).to eq(0.97)
    end

    it "raises Error on transcription failure" do
      failed_transcript = instance_double(
        AssemblyAI::Transcripts::Transcript,
        status: AssemblyAI::Transcripts::TranscriptStatus::ERROR,
        error: "Audio file could not be downloaded"
      )
      allow(mock_transcripts).to receive(:transcribe).and_return(failed_transcript)

      expect { client.transcribe(audio_url) }
        .to raise_error(AssemblyAiClient::Error, /Transcription failed/)
    end

    it "raises Error on API error" do
      allow(mock_transcripts).to receive(:transcribe).and_raise(Faraday::Error.new("Connection failed"))

      expect { client.transcribe(audio_url) }
        .to raise_error(AssemblyAiClient::Error, /AssemblyAI API error/)
    end
  end

  describe ".transcribe" do
    it "delegates to instance method" do
      mock_instance = instance_double(described_class)

      allow(described_class).to receive(:new).and_return(mock_instance)
      allow(mock_instance).to receive(:transcribe).and_return({ "text" => "test" })

      result = described_class.transcribe("https://example.com/audio.mp3")

      expect(result["text"]).to eq("test")
    end
  end

  describe ".estimate_cost_cents" do
    it "returns 0 for nil duration" do
      expect(described_class.estimate_cost_cents(nil)).to eq(0)
    end

    it "calculates cost for 1 minute" do
      # 60 seconds * 0.065 cents/second = 3.9 cents, ceil = 4 cents
      expect(described_class.estimate_cost_cents(60)).to eq(4)
    end

    it "calculates cost for 1 hour" do
      # 3600 seconds * 0.065 = 234 cents
      expect(described_class.estimate_cost_cents(3600)).to eq(234)
    end

    it "rounds up" do
      # 10 seconds * 0.065 = 0.65 cents, ceil = 1 cent
      expect(described_class.estimate_cost_cents(10)).to eq(1)
    end
  end
end
