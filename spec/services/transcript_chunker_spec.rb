require "rails_helper"

RSpec.describe TranscriptChunker do
  describe ".chunk" do
    context "with a short transcript" do
      let(:transcript) do
        {
          "text" => "Hello world. This is a test.",
          "utterances" => [
            { "text" => "Hello world.", "start" => 0, "end" => 2000, "speaker" => "A" },
            { "text" => "This is a test.", "start" => 2000, "end" => 4000, "speaker" => "B" }
          ]
        }
      end

      it "returns a single chunk" do
        chunks = described_class.chunk(transcript)
        expect(chunks.size).to eq(1)
      end

      it "includes all utterances in the chunk" do
        chunk = described_class.chunk(transcript).first
        expect(chunk.utterances.size).to eq(2)
      end

      it "sets correct start and end times" do
        chunk = described_class.chunk(transcript).first
        expect(chunk.start_time).to eq(0)
        expect(chunk.end_time).to eq(4000)
      end

      it "sets chunk index and total correctly" do
        chunk = described_class.chunk(transcript).first
        expect(chunk.index).to eq(0)
        expect(chunk.total_chunks).to eq(1)
      end
    end

    context "with a long transcript" do
      let(:long_utterance_text) { "word " * 5000 } # 5000 words per utterance
      let(:transcript) do
        {
          "text" => long_utterance_text * 4,
          "utterances" => [
            { "text" => long_utterance_text, "start" => 0, "end" => 60_000, "speaker" => "A" },
            { "text" => long_utterance_text, "start" => 60_000, "end" => 120_000, "speaker" => "B" },
            { "text" => long_utterance_text, "start" => 120_000, "end" => 180_000, "speaker" => "A" },
            { "text" => long_utterance_text, "start" => 180_000, "end" => 240_000, "speaker" => "B" }
          ]
        }
      end

      it "splits into multiple chunks" do
        chunks = described_class.chunk(transcript)
        expect(chunks.size).to be > 1
      end

      it "keeps each chunk under the word limit" do
        chunks = described_class.chunk(transcript)
        # Each chunk should be <= TARGET_WORDS_PER_CHUNK plus one utterance overage
        # (we don't split mid-utterance)
        chunks.each do |chunk|
          expect(chunk.word_count).to be <= 15_000 # Some buffer for the format overhead
        end
      end

      it "sets index and total correctly for each chunk" do
        chunks = described_class.chunk(transcript)
        chunks.each_with_index do |chunk, idx|
          expect(chunk.index).to eq(idx)
          expect(chunk.total_chunks).to eq(chunks.size)
        end
      end
    end

    context "preserves time ordering" do
      let(:transcript) do
        {
          "utterances" => [
            { "text" => "First utterance.", "start" => 0, "end" => 1000, "speaker" => "A" },
            { "text" => "Second utterance.", "start" => 1000, "end" => 2000, "speaker" => "B" },
            { "text" => "Third utterance.", "start" => 2000, "end" => 3000, "speaker" => "A" }
          ]
        }
      end

      it "maintains chronological order of utterances" do
        chunks = described_class.chunk(transcript)
        all_utterances = chunks.flat_map(&:utterances)
        start_times = all_utterances.map { |u| u["start"] }
        expect(start_times).to eq(start_times.sort)
      end

      it "has non-overlapping chunk time ranges" do
        # Add more utterances to force multiple chunks
        large_text = "word " * 6000
        transcript_with_chunks = {
          "utterances" => [
            { "text" => large_text, "start" => 0, "end" => 60_000, "speaker" => "A" },
            { "text" => large_text, "start" => 60_000, "end" => 120_000, "speaker" => "B" },
            { "text" => large_text, "start" => 120_000, "end" => 180_000, "speaker" => "A" }
          ]
        }

        chunks = described_class.chunk(transcript_with_chunks)
        next if chunks.size < 2

        chunks.each_cons(2) do |prev_chunk, next_chunk|
          expect(prev_chunk.end_time).to be <= next_chunk.start_time
        end
      end
    end

    context "handles JSON string input" do
      let(:transcript_hash) do
        {
          "utterances" => [
            { "text" => "Hello from JSON.", "start" => 0, "end" => 1000, "speaker" => "A" }
          ]
        }
      end

      it "parses JSON string input correctly" do
        json_string = transcript_hash.to_json
        chunks = described_class.chunk(json_string)

        expect(chunks.size).to eq(1)
        expect(chunks.first.utterances.first["text"]).to eq("Hello from JSON.")
      end
    end

    context "formats text with timestamps and speaker labels" do
      let(:transcript) do
        {
          "utterances" => [
            { "text" => "Good morning everyone.", "start" => 65_000, "end" => 68_000, "speaker" => "A" },
            { "text" => "Welcome to the show.", "start" => 68_000, "end" => 72_000, "speaker" => "B" }
          ]
        }
      end

      it "includes timestamp in formatted text" do
        chunk = described_class.chunk(transcript).first
        # 65000ms = 1:05
        expect(chunk.formatted_text).to include("[01:05]")
      end

      it "includes speaker labels in formatted text" do
        chunk = described_class.chunk(transcript).first
        expect(chunk.formatted_text).to include("Speaker A:")
        expect(chunk.formatted_text).to include("Speaker B:")
      end

      it "includes utterance text in formatted output" do
        chunk = described_class.chunk(transcript).first
        expect(chunk.formatted_text).to include("Good morning everyone.")
        expect(chunk.formatted_text).to include("Welcome to the show.")
      end
    end

    context "handles transcript without utterances" do
      let(:transcript) do
        {
          "text" => "This is just raw text without utterances.",
          "audio_duration" => 30
        }
      end

      it "returns a fallback chunk with the full text" do
        chunks = described_class.chunk(transcript)
        expect(chunks.size).to eq(1)
        expect(chunks.first.formatted_text).to eq("This is just raw text without utterances.")
      end

      it "sets appropriate metadata on fallback chunk" do
        chunk = described_class.chunk(transcript).first
        expect(chunk.start_time).to eq(0)
        expect(chunk.end_time).to eq(30_000) # audio_duration * 1000
        expect(chunk.index).to eq(0)
        expect(chunk.total_chunks).to eq(1)
      end
    end

    context "handles empty utterances array" do
      let(:transcript) do
        {
          "text" => "Some text here.",
          "utterances" => []
        }
      end

      it "returns a fallback chunk" do
        chunks = described_class.chunk(transcript)
        expect(chunks.size).to eq(1)
        expect(chunks.first.formatted_text).to eq("Some text here.")
      end
    end
  end

  describe ".estimate_tokens" do
    it "estimates tokens based on word count with multiplier" do
      text = "one two three four five" # 5 words
      # 5 * 1.35 = 6.75, ceil = 7
      expect(described_class.estimate_tokens(text)).to eq(7)
    end

    it "returns 0 for empty text" do
      expect(described_class.estimate_tokens("")).to eq(0)
    end

    it "returns 0 for nil" do
      expect(described_class.estimate_tokens(nil)).to eq(0)
    end

    it "handles text with various whitespace" do
      text = "word1   word2\tword3\nword4" # 4 words despite varied whitespace
      # 4 * 1.35 = 5.4, ceil = 6
      expect(described_class.estimate_tokens(text)).to eq(6)
    end
  end
end
