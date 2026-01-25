require "rails_helper"

RSpec.describe WhisperClient do
  describe "#transcribe" do
    let(:audio_file) { Tempfile.new([ "test", ".mp3" ]) }
    let(:client) { described_class.new(api_key: "test-api-key") }
    let(:mock_openai_client) { instance_double(OpenAI::Client) }
    let(:mock_audio) { double("audio") }

    let(:api_response) do
      {
        "text" => "Welcome to the show. Today we're discussing important topics.",
        "segments" => [
          { "start" => 0.0, "end" => 2.5, "text" => "Welcome to the show." },
          { "start" => 2.5, "end" => 6.0, "text" => "Today we're discussing important topics." }
        ],
        "language" => "en",
        "duration" => 6.0
      }
    end

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
      allow(mock_openai_client).to receive(:audio).and_return(mock_audio)
    end

    after do
      audio_file.close
      audio_file.unlink
    end

    it "calls OpenAI Whisper API with correct parameters" do
      allow(mock_audio).to receive(:transcribe).and_return(api_response)

      client.transcribe(audio_file)

      expect(mock_audio).to have_received(:transcribe).with(
        parameters: {
          model: "whisper-1",
          file: audio_file,
          response_format: "verbose_json",
          timestamp_granularities: [ "segment" ]
        }
      )
    end

    it "returns the API response" do
      allow(mock_audio).to receive(:transcribe).and_return(api_response)

      result = client.transcribe(audio_file)

      expect(result["text"]).to eq("Welcome to the show. Today we're discussing important topics.")
      expect(result["segments"].length).to eq(2)
      expect(result["language"]).to eq("en")
    end

    it "raises Error on API failure" do
      allow(mock_audio).to receive(:transcribe).and_raise(Faraday::Error.new("Connection failed"))

      expect { client.transcribe(audio_file) }
        .to raise_error(WhisperClient::Error, /Whisper API error/)
    end
  end

  describe ".transcribe" do
    it "delegates to instance method" do
      audio_file = Tempfile.new([ "test", ".mp3" ])
      mock_instance = instance_double(described_class)

      allow(described_class).to receive(:new).and_return(mock_instance)
      allow(mock_instance).to receive(:transcribe).and_return({ "text" => "test" })

      result = described_class.transcribe(audio_file)

      expect(result["text"]).to eq("test")
      audio_file.close
      audio_file.unlink
    end
  end

  describe ".estimate_cost_cents" do
    it "returns 0 for nil duration" do
      expect(described_class.estimate_cost_cents(nil)).to eq(0)
    end

    it "calculates cost for exact minute" do
      # 60 seconds = 1 minute = 0.6 cents, ceil = 1 cent
      expect(described_class.estimate_cost_cents(60)).to eq(1)
    end

    it "calculates cost for 1 hour" do
      # 3600 seconds = 60 minutes = 36 cents
      expect(described_class.estimate_cost_cents(3600)).to eq(36)
    end

    it "rounds up partial minutes" do
      # 61 seconds = ceil(1.017) = 2 minutes = 1.2 cents, ceil = 2 cents
      expect(described_class.estimate_cost_cents(61)).to eq(2)
    end

    it "handles short audio" do
      # 30 seconds = ceil(0.5) = 1 minute = 0.6 cents, ceil = 1 cent
      expect(described_class.estimate_cost_cents(30)).to eq(1)
    end

    it "handles very long audio" do
      # 2 hours = 120 minutes = 72 cents
      expect(described_class.estimate_cost_cents(7200)).to eq(72)
    end
  end
end
