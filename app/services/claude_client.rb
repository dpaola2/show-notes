class ClaudeClient
  class Error < StandardError; end
  class RateLimitError < Error; end

  # Delay between API calls to avoid rate limits (in seconds)
  CHUNK_DELAY = 2

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

  CHUNK_SUMMARIZE_PROMPT = <<~PROMPT
    You are summarizing PART of a podcast episode transcript.
    This is chunk %{chunk_num} of %{total_chunks} (timestamps %{start_time} to %{end_time}).

    Create:
    1. 2-3 sections covering the main topics in THIS chunk
       - Each section should have a title and 2-4 sentence summary
       - Include approximate start/end timestamps (in seconds) relative to the original podcast

    2. 2-4 notable quotes from THIS chunk worth highlighting
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

  SYNTHESIS_PROMPT = <<~PROMPT
    You are combining summaries from multiple chunks of a podcast episode into a cohesive final summary.

    Below are summaries from %{total_chunks} consecutive chunks of the transcript.
    Merge them into a single coherent summary with:

    1. 3-6 sections covering the main topics of the ENTIRE episode
       - Combine related topics from different chunks
       - Ensure good narrative flow from beginning to end
       - Preserve the original timestamps from the chunk summaries

    2. 3-5 of the BEST quotes from across all chunks
       - Select the most impactful, insightful, or memorable quotes
       - Preserve their exact timestamps

    Return ONLY valid JSON with this exact structure (no markdown, no explanations):
    {
      "sections": [
        {"title": "...", "content": "...", "start_time": 123, "end_time": 456}
      ],
      "quotes": [
        {"text": "...", "start_time": 123, "end_time": 130}
      ]
    }

    Chunk summaries to combine:
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
  rescue Anthropic::RateLimitError => e
    raise RateLimitError, "Claude rate limit exceeded: #{e.message}"
  rescue Faraday::TooManyRequestsError => e
    raise RateLimitError, "Claude rate limit exceeded: #{e.message}"
  rescue Faraday::Error => e
    raise Error, "Claude API error: #{e.message}"
  rescue StandardError => e
    # Re-raise our own errors, wrap others
    raise e if e.is_a?(Error)

    # Check for rate limit indicators in the error message
    error_str = e.message.to_s
    if error_str.include?("rate_limit") || error_str.include?("status=>429") || error_str.include?(":status=>429")
      raise RateLimitError, "Claude rate limit exceeded: #{e.message}"
    end

    raise Error, "Claude API error: #{e.message}"
  end

  # Class method for convenience
  def self.summarize(transcript)
    new.summarize(transcript)
  end

  # Summarizes a podcast transcript using chunked processing for long transcripts
  # @param transcript [String] The transcript content (JSON with utterances)
  # @return [Hash] The summary with sections and quotes
  def summarize_chunked(transcript)
    chunks = TranscriptChunker.chunk(transcript)

    # For single chunks, delegate to the simple summarize method
    if chunks.size == 1
      Rails.logger.info "Chunked summarization: 1 chunk (using simple summarize)"
      return summarize(chunks.first.formatted_text)
    end

    Rails.logger.info "Chunked summarization: #{chunks.size} chunks"

    # Phase 1: Summarize each chunk
    chunk_summaries = chunks.map.with_index do |chunk, idx|
      Rails.logger.info "  Processing chunk #{idx + 1}/#{chunks.size} (#{chunk.word_count} words, ~#{chunk.token_estimate} tokens)"

      summary = summarize_chunk(chunk)

      # Add delay between requests to avoid rate limits (except after last chunk)
      sleep(CHUNK_DELAY) unless idx == chunks.size - 1

      summary
    end

    # Phase 2: Synthesize chunk summaries into final result
    Rails.logger.info "  Running synthesis pass..."
    sleep(CHUNK_DELAY) # Delay before synthesis
    synthesize_summaries(chunk_summaries)
  end

  # Class method for convenience
  def self.summarize_chunked(transcript)
    new.summarize_chunked(transcript)
  end

  private

  # Summarizes a single chunk of transcript
  def summarize_chunk(chunk)
    prompt = format(
      CHUNK_SUMMARIZE_PROMPT,
      chunk_num: chunk.index + 1,
      total_chunks: chunk.total_chunks,
      start_time: format_time_range(chunk.start_time),
      end_time: format_time_range(chunk.end_time)
    )

    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 2048,
      messages: [
        {
          role: "user",
          content: "#{prompt}\n\nTranscript chunk:\n#{chunk.formatted_text}"
        }
      ]
    )

    text_content = response.content&.first&.text
    raise Error, "No content in Claude response for chunk #{chunk.index + 1}" unless text_content

    parse_summary_response(text_content)
  rescue Anthropic::RateLimitError => e
    raise RateLimitError, "Claude rate limit exceeded: #{e.message}"
  rescue Faraday::TooManyRequestsError => e
    raise RateLimitError, "Claude rate limit exceeded: #{e.message}"
  rescue Faraday::Error => e
    raise Error, "Claude API error: #{e.message}"
  end

  # Synthesizes multiple chunk summaries into a final cohesive summary
  def synthesize_summaries(chunk_summaries)
    prompt = format(SYNTHESIS_PROMPT, total_chunks: chunk_summaries.size)

    # Format chunk summaries for the synthesis prompt
    summaries_text = chunk_summaries.each_with_index.map do |summary, idx|
      "--- Chunk #{idx + 1} ---\n#{summary.to_json}"
    end.join("\n\n")

    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: "#{prompt}\n\n#{summaries_text}"
        }
      ]
    )

    text_content = response.content&.first&.text
    raise Error, "No content in Claude synthesis response" unless text_content

    parse_summary_response(text_content)
  rescue Anthropic::RateLimitError => e
    raise RateLimitError, "Claude rate limit exceeded: #{e.message}"
  rescue Faraday::TooManyRequestsError => e
    raise RateLimitError, "Claude rate limit exceeded: #{e.message}"
  rescue Faraday::Error => e
    raise Error, "Claude API error: #{e.message}"
  end

  # Formats milliseconds as MM:SS for human-readable time ranges
  def format_time_range(ms)
    return "00:00" unless ms
    total_seconds = (ms / 1000.0).round
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    format("%02d:%02d", minutes, seconds)
  end

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
