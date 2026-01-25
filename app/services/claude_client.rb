class ClaudeClient
  class Error < StandardError; end

  SUMMARIZE_PROMPT = <<~PROMPT
    You are summarizing a podcast episode transcript. Create:

    1. A multi-section breakdown of the episode (3-6 sections)
       - Each section should have a title and 2-4 sentence summary
       - Include approximate start/end timestamps (in seconds)

    2. 3-5 notable quotes worth highlighting
       - Include the exact timestamp for each quote (in seconds)
       - Pick quotes that are insightful, surprising, or memorable

    Return ONLY valid JSON with this exact structure (no markdown, no explanations):
    {
      "sections": [
        {"title": "...", "content": "...", "start_time": 123, "end_time": 456}
      ],
      "quotes": [
        {"text": "...", "start_time": 123, "end_time": 130}
      ]
    }
  PROMPT

  def initialize(api_key: ENV["ANTHROPIC_API_KEY"])
    @api_key = api_key
  end

  # Summarizes a podcast transcript using Claude
  # @param transcript [String] The transcript content (JSON with segments)
  # @return [Hash] The summary with sections and quotes
  def summarize(transcript)
    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: "#{SUMMARIZE_PROMPT}\n\nTranscript:\n#{transcript}"
        }
      ]
    )

    # Extract the text content from Claude's response
    text_content = response.content&.first&.text
    raise Error, "No content in Claude response" unless text_content

    # Parse the JSON response
    parse_summary_response(text_content)
  rescue Faraday::Error => e
    raise Error, "Claude API error: #{e.message}"
  rescue StandardError => e
    # Re-raise our own errors, wrap others
    raise e if e.is_a?(Error)
    raise Error, "Claude API error: #{e.message}"
  end

  # Class method for convenience
  def self.summarize(transcript)
    new.summarize(transcript)
  end

  private

  def client
    @client ||= Anthropic::Client.new(api_key: @api_key)
  end

  def parse_summary_response(text)
    # Try to extract JSON if Claude wrapped it in markdown code blocks
    json_text = text.strip
    if json_text.start_with?("```")
      json_text = json_text.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "")
    end

    parsed = JSON.parse(json_text)

    # Validate the response structure
    unless parsed.is_a?(Hash) && parsed["sections"].is_a?(Array) && parsed["quotes"].is_a?(Array)
      raise Error, "Invalid response structure from Claude"
    end

    parsed
  rescue JSON::ParserError => e
    raise Error, "Failed to parse Claude response as JSON: #{e.message}"
  end
end
