require "net/http"
require "json"
require "digest/sha1"

class PodcastIndexClient
  BASE_URL = "https://api.podcastindex.org/api/1.0"
  USER_AGENT = "ShowNotes/1.0"

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class RateLimitError < Error; end
  class NotFoundError < Error; end

  def initialize(api_key: ENV["PODCAST_INDEX_API_KEY"], api_secret: ENV["PODCAST_INDEX_API_SECRET"])
    @api_key = api_key
    @api_secret = api_secret
  end

  def search(query, max: 20)
    response = get("/search/byterm", q: query, max: max)
    response["feeds"] || []
  end

  def podcast(feed_id)
    response = get("/podcasts/byfeedid", id: feed_id)
    response["feed"]
  end

  def episodes(feed_id, max: 100)
    response = get("/episodes/byfeedid", id: feed_id, max: max)
    response["items"] || []
  end

  private

  def get(path, params = {})
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    add_auth_headers(request)
    request["User-Agent"] = USER_AGENT

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    handle_response(response)
  end

  def add_auth_headers(request)
    timestamp = Time.now.to_i.to_s
    auth_string = "#{@api_key}#{@api_secret}#{timestamp}"
    auth_hash = Digest::SHA1.hexdigest(auth_string)

    request["X-Auth-Key"] = @api_key
    request["X-Auth-Date"] = timestamp
    request["Authorization"] = auth_hash
  end

  def handle_response(response)
    case response.code.to_i
    when 200
      JSON.parse(response.body)
    when 401
      raise AuthenticationError, "Invalid API credentials"
    when 404
      raise NotFoundError, "Resource not found"
    when 429
      raise RateLimitError, "Rate limit exceeded"
    else
      raise Error, "API error (#{response.code}): #{response.body}"
    end
  end
end
