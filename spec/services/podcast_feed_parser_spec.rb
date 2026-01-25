require "rails_helper"

RSpec.describe PodcastFeedParser do
  let(:feed_url) { "https://example.com/feed.xml" }
  let(:parser) { described_class.new(feed_url) }

  let(:sample_rss) do
    <<~RSS
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
          <title>Test Podcast</title>
          <description>A test podcast</description>
          <item>
            <title>Episode 1: The Beginning</title>
            <guid>episode-1-guid</guid>
            <description>This is the first episode description.</description>
            <enclosure url="https://example.com/episode1.mp3" type="audio/mpeg" length="12345678"/>
            <itunes:duration>1:30:45</itunes:duration>
            <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
          </item>
          <item>
            <title>Episode 2: The Continuation</title>
            <guid>episode-2-guid</guid>
            <description>This is the second episode description.</description>
            <enclosure url="https://example.com/episode2.mp3" type="audio/mpeg" length="9876543"/>
            <itunes:duration>45:30</itunes:duration>
            <pubDate>Mon, 08 Jan 2024 12:00:00 GMT</pubDate>
          </item>
          <item>
            <title>Announcement (No Audio)</title>
            <guid>announcement-guid</guid>
            <description>This item has no audio enclosure.</description>
            <pubDate>Mon, 15 Jan 2024 12:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    RSS
  end

  describe ".parse" do
    it "parses a feed and returns episodes" do
      stub_request(:get, feed_url).to_return(status: 200, body: sample_rss)

      episodes = described_class.parse(feed_url)

      expect(episodes.length).to eq(2)
    end
  end

  describe "#parse" do
    it "returns Episode structs with correct attributes" do
      stub_request(:get, feed_url).to_return(status: 200, body: sample_rss)

      episodes = parser.parse
      episode = episodes.first

      expect(episode).to be_a(PodcastFeedParser::Episode)
      expect(episode.guid).to eq("episode-1-guid")
      expect(episode.title).to eq("Episode 1: The Beginning")
      expect(episode.description).to eq("This is the first episode description.")
      expect(episode.audio_url).to eq("https://example.com/episode1.mp3")
      expect(episode.duration_seconds).to eq(5445) # 1:30:45 = 5445 seconds
      expect(episode.published_at).to be_a(Time)
    end

    it "excludes entries without audio URLs" do
      stub_request(:get, feed_url).to_return(status: 200, body: sample_rss)

      episodes = parser.parse

      expect(episodes.map(&:guid)).not_to include("announcement-guid")
    end

    it "follows redirects" do
      stub_request(:get, feed_url)
        .to_return(status: 301, headers: { "Location" => "https://new.example.com/feed.xml" })
      stub_request(:get, "https://new.example.com/feed.xml")
        .to_return(status: 200, body: sample_rss)

      episodes = parser.parse

      expect(episodes.length).to eq(2)
    end

    it "raises FetchError on HTTP failure" do
      stub_request(:get, feed_url).to_return(status: 500)

      expect { parser.parse }.to raise_error(PodcastFeedParser::FetchError, /HTTP 500/)
    end

    it "raises FetchError on network error" do
      stub_request(:get, feed_url).to_timeout

      expect { parser.parse }.to raise_error(PodcastFeedParser::FetchError, /Network error/)
    end

    it "raises ParseError on invalid feed" do
      stub_request(:get, feed_url).to_return(status: 200, body: "not valid xml at all")

      expect { parser.parse }.to raise_error(PodcastFeedParser::ParseError)
    end
  end

  describe "duration parsing" do
    it "parses HH:MM:SS format" do
      rss = create_rss_with_duration("2:15:30")
      stub_request(:get, feed_url).to_return(status: 200, body: rss)

      episode = parser.parse.first

      expect(episode.duration_seconds).to eq(8130) # 2*3600 + 15*60 + 30
    end

    it "parses MM:SS format" do
      rss = create_rss_with_duration("45:30")
      stub_request(:get, feed_url).to_return(status: 200, body: rss)

      episode = parser.parse.first

      expect(episode.duration_seconds).to eq(2730) # 45*60 + 30
    end

    it "parses seconds as string" do
      rss = create_rss_with_duration("3600")
      stub_request(:get, feed_url).to_return(status: 200, body: rss)

      episode = parser.parse.first

      expect(episode.duration_seconds).to eq(3600)
    end

    it "parses seconds with decimal" do
      rss = create_rss_with_duration("3600.5")
      stub_request(:get, feed_url).to_return(status: 200, body: rss)

      episode = parser.parse.first

      expect(episode.duration_seconds).to eq(3600)
    end

    it "handles missing duration" do
      rss = create_rss_without_duration
      stub_request(:get, feed_url).to_return(status: 200, body: rss)

      episode = parser.parse.first

      expect(episode.duration_seconds).to be_nil
    end
  end

  describe "guid extraction" do
    it "uses entry_id when available" do
      stub_request(:get, feed_url).to_return(status: 200, body: sample_rss)

      episode = parser.parse.first

      expect(episode.guid).to eq("episode-1-guid")
    end

    it "generates guid from title and date when not present" do
      rss = create_rss_without_guid
      stub_request(:get, feed_url).to_return(status: 200, body: rss)

      episode = parser.parse.first

      expect(episode.guid).to be_present
      expect(episode.guid.length).to eq(64) # SHA256 hex length
    end
  end

  private

  def create_rss_with_duration(duration)
    <<~RSS
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
          <title>Test Podcast</title>
          <item>
            <title>Test Episode</title>
            <guid>test-guid</guid>
            <enclosure url="https://example.com/test.mp3" type="audio/mpeg"/>
            <itunes:duration>#{duration}</itunes:duration>
            <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    RSS
  end

  def create_rss_without_duration
    <<~RSS
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
          <title>Test Podcast</title>
          <item>
            <title>Test Episode</title>
            <guid>test-guid</guid>
            <enclosure url="https://example.com/test.mp3" type="audio/mpeg"/>
            <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    RSS
  end

  def create_rss_without_guid
    <<~RSS
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
          <title>Test Podcast</title>
          <item>
            <title>Test Episode Without GUID</title>
            <enclosure url="https://example.com/test.mp3" type="audio/mpeg"/>
            <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    RSS
  end
end
