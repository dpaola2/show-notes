require "rails_helper"

RSpec.describe Episode, "shareable behavior", type: :model do
  describe "associations" do
    it "has many share_events" do
      episode = create(:episode)
      create(:share_event, episode: episode)
      create(:share_event, :twitter, episode: episode)

      expect(episode.share_events.count).to eq(2)
    end

    it "has one attached og_image" do
      episode = create(:episode)
      expect(episode).to respond_to(:og_image)
    end
  end

  describe "#shareable?" do
    it "returns true when episode has a summary" do
      episode = create(:episode)
      create(:summary, episode: episode)

      expect(episode.shareable?).to be true
    end

    it "returns false when episode has no summary" do
      episode = create(:episode)

      expect(episode.shareable?).to be false
    end
  end

  describe "#og_image_url" do
    it "returns nil when no og_image is attached" do
      episode = create(:episode)

      expect(episode.og_image_url).to be_nil
    end

    it "returns a URL when og_image is attached" do
      episode = create(:episode)
      episode.og_image.attach(
        io: StringIO.new("fake-image-data"),
        filename: "og_image.png",
        content_type: "image/png"
      )

      expect(episode.og_image_url).to be_present
    end
  end
end
