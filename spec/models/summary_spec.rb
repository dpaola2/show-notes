require "rails_helper"

RSpec.describe Summary, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      summary = build(:summary)
      expect(summary).to be_valid
    end

    it "requires sections" do
      summary = build(:summary, sections: nil)
      expect(summary).not_to be_valid
      expect(summary.errors[:sections]).to include("can't be blank")
    end

    it "requires quotes to be an array" do
      summary = build(:summary, quotes: nil)
      expect(summary).not_to be_valid
      expect(summary.errors[:quotes]).to include("must be an array")
    end
  end

  describe "associations" do
    it "belongs to episode" do
      episode = create(:episode)
      summary = create(:summary, episode: episode)

      expect(summary.episode).to eq(episode)
    end
  end

  describe "#update_searchable_text callback" do
    it "generates searchable_text from sections and quotes on save" do
      summary = create(:summary,
        sections: [
          { "title" => "Opening", "content" => "Welcome to the show" },
          { "title" => "Main Topic", "content" => "Deep dive into Rails" }
        ],
        quotes: [
          { "text" => "Rails is amazing" },
          { "text" => "Testing is important" }
        ]
      )

      expect(summary.searchable_text).to include("Opening")
      expect(summary.searchable_text).to include("Welcome to the show")
      expect(summary.searchable_text).to include("Main Topic")
      expect(summary.searchable_text).to include("Deep dive into Rails")
      expect(summary.searchable_text).to include("Rails is amazing")
      expect(summary.searchable_text).to include("Testing is important")
    end

    it "handles empty sections gracefully" do
      summary = build(:summary, sections: [], quotes: [ { "text" => "A quote" } ])
      # Bypass validation for this edge case test
      summary.save(validate: false)

      expect(summary.searchable_text).to eq("A quote")
    end

    it "handles empty quotes gracefully" do
      summary = build(:summary, sections: [ { "title" => "Title", "content" => "Content" } ], quotes: [])
      # Bypass validation for this edge case test
      summary.save(validate: false)

      expect(summary.searchable_text).to eq("Title Content")
    end

    it "updates searchable_text when sections change" do
      summary = create(:summary)
      original_text = summary.searchable_text

      summary.update!(sections: [ { "title" => "New Section", "content" => "Brand new content" } ])

      expect(summary.searchable_text).not_to eq(original_text)
      expect(summary.searchable_text).to include("New Section")
      expect(summary.searchable_text).to include("Brand new content")
    end
  end
end
