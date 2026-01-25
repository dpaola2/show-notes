class AssemblyAiClient
  class Error < StandardError; end

  def initialize(api_key: ENV["ASSEMBLYAI_API_KEY"])
    @api_key = api_key
  end

  # Transcribes audio from a URL using AssemblyAI
  # @param audio_url [String] Public URL of the audio file
  # @return [Hash] The transcription response with text and timestamps
  def transcribe(audio_url)
    client = AssemblyAI::Client.new(api_key: @api_key)

    transcript = client.transcripts.transcribe(
      audio_url: audio_url,
      speaker_labels: true
    )

    if transcript.status == AssemblyAI::Transcripts::TranscriptStatus::ERROR
      raise Error, "Transcription failed: #{transcript.error}"
    end

    # Return a hash compatible with our existing transcript format
    {
      "text" => transcript.text,
      "words" => transcript.words&.map do |word|
        {
          "text" => word.text,
          "start" => word.start,
          "end" => word.end_,
          "confidence" => word.confidence,
          "speaker" => word.speaker
        }
      end,
      "utterances" => transcript.utterances&.map do |utterance|
        {
          "text" => utterance.text,
          "start" => utterance.start,
          "end" => utterance.end_,
          "confidence" => utterance.confidence,
          "speaker" => utterance.speaker
        }
      end,
      "audio_duration" => transcript.audio_duration,
      "confidence" => transcript.confidence
    }
  rescue Faraday::Error => e
    raise Error, "AssemblyAI API error: #{e.message}"
  rescue StandardError => e
    raise Error, "AssemblyAI API error: #{e.message}"
  end

  # Class method for convenience
  def self.transcribe(audio_url)
    new.transcribe(audio_url)
  end

  # Estimates the cost in cents to transcribe audio of a given duration
  # Based on AssemblyAI pricing: $0.00065 per second ($0.039/min, or ~$0.65/hr)
  # Using their "Best" tier pricing
  # @param duration_seconds [Integer] Duration of audio in seconds
  # @return [Integer] Estimated cost in cents
  def self.estimate_cost_cents(duration_seconds)
    return 0 unless duration_seconds

    # $0.00065/second = 0.065 cents/second
    (duration_seconds * 0.065).ceil
  end
end
