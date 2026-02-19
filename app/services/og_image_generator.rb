class OgImageGenerator
  WIDTH = 1200
  HEIGHT = 630
  ARTWORK_SIZE = 200
  PADDING = 60
  MAX_TITLE_LENGTH = 80
  MAX_QUOTE_LENGTH = 200

  def self.generate(episode)
    new(episode).generate
  end

  def initialize(episode)
    @episode = episode
    @podcast = episode.podcast
    @summary = episode.summary
  end

  def generate
    canvas = create_canvas
    canvas = composite_artwork(canvas)
    canvas = render_text(canvas)
    begin
      canvas.write_to_buffer(".png")
    rescue Vips::Error => e
      # Artwork may have corrupt data only surfaced during lazy evaluation;
      # retry without artwork so the image still generates.
      Rails.logger.warn("OG image write failed, retrying without artwork: #{e.message}")
      canvas = create_canvas
      canvas = render_text(canvas)
      canvas.write_to_buffer(".png")
    end
  end

  private

  def create_canvas
    # Dark background — 3-band sRGB + alpha for compositing
    bg = Vips::Image.black(WIDTH, HEIGHT, bands: 3).add([ 40, 45, 65 ]).cast(:uchar)
    bg = bg.copy(interpretation: :srgb)
    alpha = Vips::Image.black(WIDTH, HEIGHT).add(255).cast(:uchar)
    bg.bandjoin(alpha)
  end

  def composite_artwork(canvas)
    artwork = fetch_artwork
    return canvas unless artwork

    # Scale artwork to fit ARTWORK_SIZE x ARTWORK_SIZE
    scale = ARTWORK_SIZE.to_f / [ artwork.width, artwork.height ].max
    artwork = artwork.resize(scale)

    # Ensure artwork has alpha channel for compositing
    artwork = artwork.bandjoin(255) if artwork.bands == 3

    x = PADDING
    y = (HEIGHT - artwork.height) / 2
    canvas.composite(artwork, :over, x: [ x ], y: [ y ])
  rescue => e
    Rails.logger.warn("OG image artwork compositing failed: #{e.message}")
    canvas
  end

  def render_text(canvas)
    text_x = PADDING + ARTWORK_SIZE + 40
    text_width = WIDTH - text_x - PADDING

    # Episode title
    title = truncate_text(@episode.title, MAX_TITLE_LENGTH)
    title_overlay = render_text_image(title, text_width, size: 36, color: "white")
    canvas = canvas.composite(title_overlay, :over, x: [ text_x ], y: [ PADDING + 20 ]) if title_overlay

    # Podcast name
    podcast_overlay = render_text_image(@podcast.title, text_width, size: 22, color: "#94a3b8")
    canvas = canvas.composite(podcast_overlay, :over, x: [ text_x ], y: [ PADDING + 80 ]) if podcast_overlay

    # Quote or excerpt
    excerpt = extract_excerpt
    if excerpt
      excerpt = truncate_text(excerpt, MAX_QUOTE_LENGTH)
      quote_text = %("#{excerpt}")
      quote_overlay = render_text_image(quote_text, text_width, size: 20, color: "#cbd5e1")
      canvas = canvas.composite(quote_overlay, :over, x: [ text_x ], y: [ HEIGHT / 2 - 20 ]) if quote_overlay
    end

    # Branding
    branding_overlay = render_text_image("Show Notes", text_width, size: 18, color: "#64748b")
    canvas = canvas.composite(branding_overlay, :over, x: [ text_x ], y: [ HEIGHT - PADDING - 20 ]) if branding_overlay

    canvas
  end

  def render_text_image(text, width, size:, color:)
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{size * 3}">
        <text x="0" y="#{size}" font-family="sans-serif" font-size="#{size}" fill="#{color}">#{escape_xml(text)}</text>
      </svg>
    SVG
    Vips::Image.svgload_buffer(svg)
  rescue => e
    Rails.logger.warn("OG image text rendering failed: #{e.message}")
    nil
  end

  def fetch_artwork
    return nil if @podcast.artwork_url.blank?

    response = Net::HTTP.get_response(URI.parse(@podcast.artwork_url))
    return nil unless response.is_a?(Net::HTTPSuccess)

    Vips::Image.new_from_buffer(response.body, "")
  rescue => e
    Rails.logger.warn("OG image artwork fetch failed: #{e.message}")
    nil
  end

  def extract_excerpt
    quotes = @summary&.quotes || []
    if quotes.any?
      quotes.first["text"]
    else
      sections = @summary&.sections || []
      sections.first&.dig("content")&.split(".")&.first
    end
  end

  def truncate_text(text, max_length)
    return text if text.length <= max_length
    text[0...(max_length - 3)] + "..."
  end

  def escape_xml(text)
    text.to_s
      .gsub("&", "&amp;")
      .gsub("<", "&lt;")
      .gsub(">", "&gt;")
      .gsub('"', "&quot;")
      .gsub("'", "&apos;")
  end
end
