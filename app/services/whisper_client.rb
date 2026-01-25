class WhisperClient
  class Error < StandardError; end

  def initialize(api_key: ENV["OPENAI_API_KEY"])
    @api_key = api_key
  end

  # Transcribes an audio file using OpenAI's Whisper API
  # @param audio_file [File, Tempfile] The audio file to transcribe
  # @return [Hash] The transcription response with segments and timestamps
  def transcribe(audio_file)
    response = client.audio.transcribe(
      parameters: {
        model: "whisper-1",
        file: audio_file,
        response_format: "verbose_json",
        timestamp_granularities: [ "segment" ]
      }
    )

    # The response includes:
    # - text: full transcript text
    # - segments: array of {start, end, text} for each segment
    # - language: detected language
    # - duration: total duration in seconds

    response
  rescue Faraday::Error => e
    raise Error, "Whisper API error: #{e.message}"
  rescue OpenAI::Error => e
    raise Error, "Whisper API error: #{e.message}"
  end

  # Class method for convenience
  def self.transcribe(audio_file)
    new.transcribe(audio_file)
  end

  # Estimates the cost in cents to transcribe audio of a given duration
  # Based on OpenAI Whisper pricing: $0.006 per minute
  # @param duration_seconds [Integer] Duration of audio in seconds
  # @return [Integer] Estimated cost in cents
  def self.estimate_cost_cents(duration_seconds)
    return 0 unless duration_seconds

    minutes = (duration_seconds / 60.0).ceil
    (minutes * 0.6).ceil # $0.006/min = 0.6 cents/min
  end

  private

  def client
    @client ||= OpenAI::Client.new(access_token: @api_key)
  end
end
