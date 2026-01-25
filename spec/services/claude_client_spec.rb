require "rails_helper"

RSpec.describe ClaudeClient do
  describe "#summarize" do
    let(:client) { described_class.new(api_key: "test-api-key") }
    let(:mock_anthropic_client) { instance_double(Anthropic::Client) }
    let(:mock_messages) { double("messages") }

    let(:transcript) do
      {
        "segments" => [
          { "start" => 0.0, "end" => 10.0, "text" => "Welcome to the show." },
          { "start" => 10.0, "end" => 30.0, "text" => "Today we discuss important topics." }
        ]
      }.to_json
    end

    let(:valid_summary) do
      {
        "sections" => [
          {
            "title" => "Introduction",
            "content" => "The host welcomes listeners.",
            "start_time" => 0,
            "end_time" => 10
          },
          {
            "title" => "Main Discussion",
            "content" => "Key topics are explored.",
            "start_time" => 10,
            "end_time" => 30
          }
        ],
        "quotes" => [
          {
            "text" => "Today we discuss important topics.",
            "start_time" => 10,
            "end_time" => 15
          }
        ]
      }
    end

    let(:api_response) do
      content_block = double("content_block", text: valid_summary.to_json)
      double("response", content: [ content_block ])
    end

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
      allow(mock_anthropic_client).to receive(:messages).and_return(mock_messages)
    end

    it "calls Claude API with the summarization prompt" do
      allow(mock_messages).to receive(:create).and_return(api_response)

      client.summarize(transcript)

      expect(mock_messages).to have_received(:create).with(
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        messages: [
          {
            role: "user",
            content: a_string_including("summarizing a podcast episode transcript")
                      .and(including(transcript))
          }
        ]
      )
    end

    it "returns parsed sections and quotes" do
      allow(mock_messages).to receive(:create).and_return(api_response)

      result = client.summarize(transcript)

      expect(result["sections"]).to be_an(Array)
      expect(result["sections"].length).to eq(2)
      expect(result["sections"].first["title"]).to eq("Introduction")
      expect(result["quotes"]).to be_an(Array)
      expect(result["quotes"].first["text"]).to eq("Today we discuss important topics.")
    end

    it "handles JSON wrapped in markdown code blocks" do
      content_block = double("content_block", text: "```json\n#{valid_summary.to_json}\n```")
      wrapped_response = double("response", content: [ content_block ])
      allow(mock_messages).to receive(:create).and_return(wrapped_response)

      result = client.summarize(transcript)

      expect(result["sections"]).to be_an(Array)
    end

    it "raises Error when response has no content" do
      empty_response = double("response", content: [])
      allow(mock_messages).to receive(:create).and_return(empty_response)

      expect { client.summarize(transcript) }
        .to raise_error(ClaudeClient::Error, /No content in Claude response/)
    end

    it "raises Error when response is not valid JSON" do
      content_block = double("content_block", text: "This is not JSON")
      invalid_response = double("response", content: [ content_block ])
      allow(mock_messages).to receive(:create).and_return(invalid_response)

      expect { client.summarize(transcript) }
        .to raise_error(ClaudeClient::Error, /Failed to parse Claude response/)
    end

    it "raises Error when response structure is invalid" do
      content_block = double("content_block", text: '{"wrong": "structure"}')
      wrong_structure_response = double("response", content: [ content_block ])
      allow(mock_messages).to receive(:create).and_return(wrong_structure_response)

      expect { client.summarize(transcript) }
        .to raise_error(ClaudeClient::Error, /Invalid response structure/)
    end

    it "raises Error on API failure" do
      allow(mock_messages).to receive(:create)
        .and_raise(Faraday::Error.new("Connection failed"))

      expect { client.summarize(transcript) }
        .to raise_error(ClaudeClient::Error, /Claude API error/)
    end
  end

  describe ".summarize" do
    it "delegates to instance method" do
      mock_instance = instance_double(described_class)

      allow(described_class).to receive(:new).and_return(mock_instance)
      allow(mock_instance).to receive(:summarize).and_return({ "sections" => [], "quotes" => [] })

      result = described_class.summarize("transcript")

      expect(result).to eq({ "sections" => [], "quotes" => [] })
    end
  end
end
