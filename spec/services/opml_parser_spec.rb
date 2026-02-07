require "rails_helper"

RSpec.describe OpmlParser do
  describe ".parse" do
    context "with a valid OPML file containing podcast feeds" do
      let(:xml) { file_fixture("valid_podcasts.opml").read }

      it "returns an array of Feed structs" do
        feeds = described_class.parse(xml)

        expect(feeds).to be_an(Array)
        expect(feeds.length).to eq(3)
        expect(feeds.first).to be_a(OpmlParser::Feed)
      end

      it "extracts feed URLs from xmlUrl attributes" do
        feeds = described_class.parse(xml)

        expect(feeds.map(&:feed_url)).to contain_exactly(
          "https://feeds.simplecast.com/the-daily",
          "https://feeds.example.com/acquired",
          "https://feeds.example.com/hardcore-history"
        )
      end

      it "extracts titles from text attributes" do
        feeds = described_class.parse(xml)

        expect(feeds.map(&:title)).to contain_exactly(
          "The Daily",
          "Acquired",
          "Hardcore History"
        )
      end
    end

    context "IMP-004: with title attribute instead of text" do
      let(:xml) do
        <<~OPML
          <?xml version="1.0" encoding="UTF-8"?>
          <opml version="2.0">
            <head><title>Test</title></head>
            <body>
              <outline title="Title Attribute Pod" xmlUrl="https://feeds.example.com/title-pod" />
            </body>
          </opml>
        OPML
      end

      it "falls back to the title attribute when text is not present" do
        feeds = described_class.parse(xml)

        expect(feeds.first.title).to eq("Title Attribute Pod")
      end
    end

    context "with nested folder structure" do
      let(:xml) { file_fixture("nested_folders.opml").read }

      it "flattens nested folders into a single list of feeds" do
        feeds = described_class.parse(xml)

        expect(feeds.length).to eq(5)
      end

      it "extracts feeds from all nesting levels" do
        feeds = described_class.parse(xml)
        urls = feeds.map(&:feed_url)

        # Nested inside "Technology" folder
        expect(urls).to include("https://feeds.example.com/atp")
        expect(urls).to include("https://feeds.example.com/upgrade")
        # Nested inside "Business" folder
        expect(urls).to include("https://feeds.example.com/acquired")
        expect(urls).to include("https://feeds.example.com/invest")
        # Top-level (not in a folder)
        expect(urls).to include("https://feeds.example.com/unfiled-show")
      end
    end

    context "with duplicate feed URLs" do
      let(:xml) { file_fixture("duplicate_feeds.opml").read }

      it "deduplicates feeds by feed_url" do
        feeds = described_class.parse(xml)

        expect(feeds.length).to eq(2)
        expect(feeds.map(&:feed_url)).to contain_exactly(
          "https://feeds.simplecast.com/the-daily",
          "https://feeds.example.com/acquired"
        )
      end
    end

    context "IMP-007: with malformed XML" do
      let(:xml) { "this is not xml at all" }

      it "raises OpmlParser::Error" do
        expect { described_class.parse(xml) }.to raise_error(OpmlParser::Error)
      end
    end

    context "IMP-007: with valid XML but no podcast feeds (zero xmlUrl attributes)" do
      let(:xml) { file_fixture("empty_feeds.opml").read }

      it "raises OpmlParser::Error with a distinct message about no feeds found" do
        expect { described_class.parse(xml) }.to raise_error(
          OpmlParser::Error, /no podcast feeds found/i
        )
      end
    end

    context "IMP-007: with an empty string" do
      it "raises OpmlParser::Error" do
        expect { described_class.parse("") }.to raise_error(OpmlParser::Error)
      end
    end

    context "with outlines that have no xmlUrl (non-podcast entries)" do
      let(:xml) do
        <<~OPML
          <?xml version="1.0" encoding="UTF-8"?>
          <opml version="2.0">
            <head><title>Mixed</title></head>
            <body>
              <outline text="Blog" htmlUrl="https://example.com/blog" />
              <outline text="Real Podcast" xmlUrl="https://feeds.example.com/real" />
              <outline text="Category Only" />
            </body>
          </opml>
        OPML
      end

      it "only includes outlines with xmlUrl attributes" do
        feeds = described_class.parse(xml)

        expect(feeds.length).to eq(1)
        expect(feeds.first.feed_url).to eq("https://feeds.example.com/real")
      end
    end
  end
end
