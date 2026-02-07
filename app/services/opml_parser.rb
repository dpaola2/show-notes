class OpmlParser
  class Error < StandardError; end

  Feed = Struct.new(:title, :feed_url, keyword_init: true)

  def self.parse(xml_string)
    new(xml_string).parse
  end

  def initialize(xml_string)
    @xml_string = xml_string
  end

  def parse
    raise Error, "No content provided" if @xml_string.blank?

    doc = Nokogiri::XML(@xml_string) { |config| config.strict }

    outlines = doc.xpath("//outline[@xmlUrl]")
    raise Error, "No podcast feeds found in this file" if outlines.empty?

    outlines.map { |outline|
      Feed.new(
        title: outline["text"] || outline["title"],
        feed_url: outline["xmlUrl"]
      )
    }.uniq(&:feed_url)
  rescue Nokogiri::XML::SyntaxError
    raise Error, "Invalid XML — could not parse the file"
  end
end
