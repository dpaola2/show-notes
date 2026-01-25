class TranscriptChunker
  # Target ~12,000 words per chunk (~15,600 tokens at 1.3x multiplier)
  # This keeps us well under Claude's rate limits while providing enough context
  TARGET_WORDS_PER_CHUNK = 12_000

  # Multiplier to estimate tokens from word count
  # Claude tokenization typically runs 1.3-1.4x word count for English text
  TOKEN_MULTIPLIER = 1.35

  Chunk = Struct.new(:utterances, :start_time, :end_time, :formatted_text, :word_count, :token_estimate, :index, :total_chunks, keyword_init: true)

  class << self
    # Splits a transcript into chunks based on utterances
    # @param transcript [String, Hash] JSON string or parsed Hash with utterances
    # @return [Array<Chunk>] Array of chunks, each containing utterances and metadata
    def chunk(transcript)
      data = parse_transcript(transcript)
      utterances = data["utterances"] || []

      # If no utterances, fall back to a single chunk with full text
      if utterances.empty?
        return [build_fallback_chunk(data)]
      end

      chunks = split_into_chunks(utterances)
      finalize_chunks(chunks)
    end

    # Estimates token count from text
    # @param text [String] Text to estimate
    # @return [Integer] Estimated token count
    def estimate_tokens(text)
      return 0 if text.nil? || text.empty?
      (text.split(/\s+/).size * TOKEN_MULTIPLIER).ceil
    end

    private

    def parse_transcript(transcript)
      case transcript
      when String
        JSON.parse(transcript)
      when Hash
        transcript
      else
        raise ArgumentError, "Transcript must be a String or Hash, got #{transcript.class}"
      end
    end

    def split_into_chunks(utterances)
      chunks = []
      current_chunk_utterances = []
      current_word_count = 0

      utterances.each do |utterance|
        utterance_word_count = word_count(utterance["text"])

        # If adding this utterance would exceed target, start a new chunk
        # (unless current chunk is empty - never leave an utterance orphaned)
        if current_word_count + utterance_word_count > TARGET_WORDS_PER_CHUNK && !current_chunk_utterances.empty?
          chunks << current_chunk_utterances
          current_chunk_utterances = []
          current_word_count = 0
        end

        current_chunk_utterances << utterance
        current_word_count += utterance_word_count
      end

      # Don't forget the last chunk
      chunks << current_chunk_utterances unless current_chunk_utterances.empty?

      chunks
    end

    def finalize_chunks(chunk_arrays)
      total = chunk_arrays.size

      chunk_arrays.each_with_index.map do |utterances, index|
        formatted = format_utterances(utterances)
        words = word_count(formatted)

        Chunk.new(
          utterances: utterances,
          start_time: utterances.first["start"],
          end_time: utterances.last["end"],
          formatted_text: formatted,
          word_count: words,
          token_estimate: estimate_tokens(formatted),
          index: index,
          total_chunks: total
        )
      end
    end

    def format_utterances(utterances)
      utterances.map do |u|
        timestamp = format_timestamp(u["start"])
        speaker = u["speaker"] ? "Speaker #{u['speaker']}" : "Speaker"
        "[#{timestamp}] #{speaker}: #{u['text']}"
      end.join("\n\n")
    end

    def format_timestamp(ms)
      return "00:00" unless ms
      total_seconds = (ms / 1000.0).round
      minutes = total_seconds / 60
      seconds = total_seconds % 60
      format("%02d:%02d", minutes, seconds)
    end

    def word_count(text)
      return 0 if text.nil? || text.empty?
      text.split(/\s+/).size
    end

    def build_fallback_chunk(data)
      text = data["text"] || ""
      words = word_count(text)

      Chunk.new(
        utterances: [],
        start_time: 0,
        end_time: data["audio_duration"]&.*(1000) || 0,
        formatted_text: text,
        word_count: words,
        token_estimate: estimate_tokens(text),
        index: 0,
        total_chunks: 1
      )
    end
  end
end
