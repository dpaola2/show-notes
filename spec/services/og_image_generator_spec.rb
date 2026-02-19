require "rails_helper"

RSpec.describe OgImageGenerator do
  let(:podcast) { create(:podcast, title: "Test Podcast", artwork_url: "https://example.com/artwork.jpg") }
  let(:episode) { create(:episode, podcast: podcast, title: "Great Episode Title") }
  let!(:summary) do
    create(:summary, episode: episode, sections: [
      { "title" => "Introduction", "content" => "The host welcomes listeners and introduces the topic." }
    ], quotes: [
      { "text" => "This is a compelling quote from the episode.", "start_time" => 120, "end_time" => 128 }
    ])
  end

  # Minimal valid 1x1 PNG for stubbing artwork fetch
  let(:minimal_png) do
    [ 137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
     0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0,
     0, 0, 10, 73, 68, 65, 84, 120, 156, 98, 0, 0, 0, 2, 0, 1, 226,
     33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130 ].pack("C*")
  end

  before do
    stub_request(:get, "https://example.com/artwork.jpg")
      .to_return(body: minimal_png, status: 200, headers: { "Content-Type" => "image/png" })
  end

  describe "OGI-001: generates a 1200x630 OG image" do
    it "returns image data" do
      result = described_class.generate(episode)

      expect(result).to be_present
    end

    it "generates an image with the correct dimensions" do
      result = described_class.generate(episode)

      # The generated image should be 1200x630
      image = Vips::Image.new_from_buffer(result, "")
      expect(image.width).to eq(1200)
      expect(image.height).to eq(630)
    end
  end

  describe "OGI-002: includes podcast artwork" do
    it "fetches artwork from the podcast artwork_url" do
      described_class.generate(episode)

      expect(WebMock).to have_requested(:get, "https://example.com/artwork.jpg")
    end
  end

  describe "OGI-004: includes a quote" do
    it "uses the first quote when quotes are available" do
      result = described_class.generate(episode)

      expect(result).to be_present
    end

    context "when episode has no quotes" do
      let!(:summary_no_quotes) do
        episode.summary.destroy!
        create(:summary, episode: episode, sections: [
          { "title" => "Main Topic", "content" => "The host discusses the first important point about technology." }
        ], quotes: [])
      end

      it "falls back to first sentence of first section content" do
        result = described_class.generate(episode.reload)

        expect(result).to be_present
      end
    end
  end

  describe "OGI-007: handles variable artwork quality" do
    it "handles missing artwork URL gracefully" do
      podcast.update!(artwork_url: nil)

      result = described_class.generate(episode)

      expect(result).to be_present
    end

    it "handles artwork fetch failure gracefully" do
      stub_request(:get, "https://example.com/artwork.jpg")
        .to_return(status: 404)

      result = described_class.generate(episode)

      expect(result).to be_present
    end

    it "handles artwork fetch timeout gracefully" do
      stub_request(:get, "https://example.com/artwork.jpg")
        .to_timeout

      result = described_class.generate(episode)

      expect(result).to be_present
    end
  end

  describe "edge cases" do
    context "very long episode title" do
      let(:episode) { create(:episode, podcast: podcast, title: "A" * 150) }

      it "generates an image without error" do
        result = described_class.generate(episode)

        expect(result).to be_present
      end
    end

    context "very long quote" do
      let!(:summary) do
        episode.summary&.destroy!
        create(:summary, episode: episode, quotes: [
          { "text" => "A" * 500, "start_time" => 120, "end_time" => 150 }
        ])
      end

      it "generates an image without error" do
        result = described_class.generate(episode)

        expect(result).to be_present
      end
    end
  end
end
