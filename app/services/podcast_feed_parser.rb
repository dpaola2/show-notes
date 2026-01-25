require "feedjira"
require "net/http"

class PodcastFeedParser
  class Error < StandardError; end
  class FetchError < Error; end
  class ParseError < Error; end

  Episode = Struct.new(:guid, :title, :description, :audio_url, :duration_seconds, :published_at, keyword_init: true)

  def self.parse(feed_url)
    new(feed_url).parse
  end

  def initialize(feed_url)
    @feed_url = feed_url
  end

  def parse
    xml = fetch_feed
    feed = parse_feed(xml)
    extract_episodes(feed)
  end

  private

  def fetch_feed
    uri = URI(@feed_url)
    response = Net::HTTP.get_response(uri)

    # Follow redirects (up to 5)
    redirects = 0
    while response.is_a?(Net::HTTPRedirection) && redirects < 5
      uri = URI(response["location"])
      response = Net::HTTP.get_response(uri)
      redirects += 1
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise FetchError, "Failed to fetch feed: HTTP #{response.code}"
    end

    response.body
  rescue SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout => e
    raise FetchError, "Network error fetching feed: #{e.message}"
  end

  def parse_feed(xml)
    Feedjira.parse(xml)
  rescue Feedjira::NoParserAvailable => e
    raise ParseError, "Unable to parse feed: #{e.message}"
  end

  def extract_episodes(feed)
    feed.entries.map do |entry|
      Episode.new(
        guid: extract_guid(entry),
        title: entry.title&.strip,
        description: extract_description(entry),
        audio_url: extract_audio_url(entry),
        duration_seconds: extract_duration(entry),
        published_at: entry.published
      )
    end.select { |ep| ep.audio_url.present? }
  end

  def extract_guid(entry)
    entry.entry_id || entry.url || Digest::SHA256.hexdigest("#{entry.title}-#{entry.published}")
  end

  def extract_description(entry)
    # Prefer content over summary, strip HTML if needed
    content = entry.content || entry.summary || ""
    content.strip
  end

  def extract_audio_url(entry)
    # Check enclosure first (standard podcast location)
    if entry.respond_to?(:enclosure_url) && entry.enclosure_url.present?
      return entry.enclosure_url
    end

    # Feedjira may store enclosure differently
    if entry.respond_to?(:enclosure) && entry.enclosure.present?
      enclosure = entry.enclosure
      return enclosure.url if enclosure.respond_to?(:url)
      return enclosure if enclosure.is_a?(String)
    end

    nil
  end

  def extract_duration(entry)
    # iTunes duration is commonly used in podcast feeds
    duration = entry.try(:itunes_duration) || entry.try(:duration)
    return nil unless duration

    parse_duration(duration)
  end

  def parse_duration(duration)
    return duration if duration.is_a?(Integer)

    # Handle common duration formats:
    # "3600" (seconds as string)
    # "1:00:00" (HH:MM:SS)
    # "60:00" (MM:SS)
    # "3600.0" (seconds with decimal)

    duration = duration.to_s.strip

    if duration.include?(":")
      parts = duration.split(":").map(&:to_i)
      case parts.length
      when 3 # HH:MM:SS
        parts[0] * 3600 + parts[1] * 60 + parts[2]
      when 2 # MM:SS
        parts[0] * 60 + parts[1]
      else
        duration.to_i
      end
    else
      duration.to_f.to_i
    end
  rescue
    nil
  end
end
