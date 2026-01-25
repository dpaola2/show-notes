require "rails_helper"

RSpec.describe PodcastIndexClient do
  let(:api_key) { "test-api-key" }
  let(:api_secret) { "test-api-secret" }
  let(:client) { described_class.new(api_key: api_key, api_secret: api_secret) }

  describe "#search" do
    let(:search_response) do
      {
        "status" => "true",
        "feeds" => [
          {
            "id" => 123,
            "title" => "Test Podcast",
            "author" => "Test Author",
            "description" => "A test podcast description",
            "url" => "https://example.com/feed.xml",
            "artwork" => "https://example.com/artwork.jpg"
          },
          {
            "id" => 456,
            "title" => "Another Podcast",
            "author" => "Another Author",
            "description" => "Another description",
            "url" => "https://example.com/feed2.xml",
            "artwork" => "https://example.com/artwork2.jpg"
          }
        ],
        "count" => 2
      }
    end

    it "returns podcasts matching the query" do
      stub_request(:get, /api\.podcastindex\.org.*search\/byterm/)
        .with(query: hash_including(q: "test", max: "20"))
        .to_return(status: 200, body: search_response.to_json)

      results = client.search("test")

      expect(results.length).to eq(2)
      expect(results.first["title"]).to eq("Test Podcast")
      expect(results.first["id"]).to eq(123)
    end

    it "returns empty array when no results found" do
      stub_request(:get, /api\.podcastindex\.org.*search\/byterm/)
        .to_return(status: 200, body: { "status" => "true", "feeds" => [], "count" => 0 }.to_json)

      results = client.search("nonexistent")

      expect(results).to eq([])
    end

    it "includes proper auth headers" do
      stub_request(:get, /api\.podcastindex\.org.*search\/byterm/)
        .to_return(status: 200, body: search_response.to_json)

      freeze_time do
        client.search("test")

        expected_hash = Digest::SHA1.hexdigest("#{api_key}#{api_secret}#{Time.now.to_i}")

        expect(WebMock).to have_requested(:get, /api\.podcastindex\.org/)
          .with(headers: {
            "X-Auth-Key" => api_key,
            "X-Auth-Date" => Time.now.to_i.to_s,
            "Authorization" => expected_hash
          })
      end
    end

    it "allows custom max results" do
      stub_request(:get, /api\.podcastindex\.org.*search\/byterm/)
        .with(query: hash_including(max: "50"))
        .to_return(status: 200, body: search_response.to_json)

      client.search("test", max: 50)

      expect(WebMock).to have_requested(:get, /api\.podcastindex\.org/)
        .with(query: hash_including(max: "50"))
    end
  end

  describe "#podcast" do
    let(:podcast_response) do
      {
        "status" => "true",
        "feed" => {
          "id" => 123,
          "title" => "Test Podcast",
          "author" => "Test Author",
          "description" => "A test podcast description",
          "url" => "https://example.com/feed.xml",
          "artwork" => "https://example.com/artwork.jpg"
        }
      }
    end

    it "returns podcast details by feed ID" do
      stub_request(:get, /api\.podcastindex\.org.*podcasts\/byfeedid/)
        .with(query: hash_including(id: "123"))
        .to_return(status: 200, body: podcast_response.to_json)

      result = client.podcast(123)

      expect(result["title"]).to eq("Test Podcast")
      expect(result["id"]).to eq(123)
    end
  end

  describe "#episodes" do
    let(:episodes_response) do
      {
        "status" => "true",
        "items" => [
          {
            "id" => 1001,
            "title" => "Episode 1",
            "description" => "First episode",
            "enclosureUrl" => "https://example.com/episode1.mp3",
            "duration" => 3600,
            "datePublished" => 1700000000
          },
          {
            "id" => 1002,
            "title" => "Episode 2",
            "description" => "Second episode",
            "enclosureUrl" => "https://example.com/episode2.mp3",
            "duration" => 2400,
            "datePublished" => 1700100000
          }
        ],
        "count" => 2
      }
    end

    it "returns episodes for a podcast" do
      stub_request(:get, /api\.podcastindex\.org.*episodes\/byfeedid/)
        .with(query: hash_including(id: "123"))
        .to_return(status: 200, body: episodes_response.to_json)

      results = client.episodes(123)

      expect(results.length).to eq(2)
      expect(results.first["title"]).to eq("Episode 1")
      expect(results.first["enclosureUrl"]).to eq("https://example.com/episode1.mp3")
    end

    it "returns empty array when no episodes found" do
      stub_request(:get, /api\.podcastindex\.org.*episodes\/byfeedid/)
        .to_return(status: 200, body: { "status" => "true", "items" => [], "count" => 0 }.to_json)

      results = client.episodes(123)

      expect(results).to eq([])
    end

    it "allows custom max results" do
      stub_request(:get, /api\.podcastindex\.org.*episodes\/byfeedid/)
        .with(query: hash_including(max: "10"))
        .to_return(status: 200, body: episodes_response.to_json)

      client.episodes(123, max: 10)

      expect(WebMock).to have_requested(:get, /api\.podcastindex\.org/)
        .with(query: hash_including(max: "10"))
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401 response" do
      stub_request(:get, /api\.podcastindex\.org/)
        .to_return(status: 401, body: { "error" => "Invalid credentials" }.to_json)

      expect { client.search("test") }.to raise_error(PodcastIndexClient::AuthenticationError)
    end

    it "raises NotFoundError on 404 response" do
      stub_request(:get, /api\.podcastindex\.org/)
        .to_return(status: 404, body: { "error" => "Not found" }.to_json)

      expect { client.podcast(999999) }.to raise_error(PodcastIndexClient::NotFoundError)
    end

    it "raises RateLimitError on 429 response" do
      stub_request(:get, /api\.podcastindex\.org/)
        .to_return(status: 429, body: { "error" => "Rate limit exceeded" }.to_json)

      expect { client.search("test") }.to raise_error(PodcastIndexClient::RateLimitError)
    end

    it "raises Error on other error codes" do
      stub_request(:get, /api\.podcastindex\.org/)
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.search("test") }.to raise_error(PodcastIndexClient::Error, /API error \(500\)/)
    end
  end

  describe "default configuration" do
    around do |example|
      original_key = ENV["PODCAST_INDEX_API_KEY"]
      original_secret = ENV["PODCAST_INDEX_API_SECRET"]
      ENV["PODCAST_INDEX_API_KEY"] = "env-key"
      ENV["PODCAST_INDEX_API_SECRET"] = "env-secret"
      example.run
      ENV["PODCAST_INDEX_API_KEY"] = original_key
      ENV["PODCAST_INDEX_API_SECRET"] = original_secret
    end

    it "uses environment variables when not provided" do
      stub_request(:get, /api\.podcastindex\.org/)
        .to_return(status: 200, body: { "feeds" => [] }.to_json)

      default_client = described_class.new

      freeze_time do
        default_client.search("test")
        expected_hash = Digest::SHA1.hexdigest("env-keyenv-secret#{Time.now.to_i}")

        expect(WebMock).to have_requested(:get, /api\.podcastindex\.org/)
          .with(headers: { "X-Auth-Key" => "env-key", "Authorization" => expected_hash })
      end
    end
  end
end
