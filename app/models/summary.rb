class Summary < ApplicationRecord
  belongs_to :episode

  validates :sections, presence: true
  validates :quotes, presence: true

  before_save :update_searchable_text

  private

  # Extract text from jsonb sections for full-text search
  def update_searchable_text
    section_texts = (sections || []).map { |s| "#{s['title']} #{s['content']}" }
    quote_texts = (quotes || []).map { |q| q["text"] }
    self.searchable_text = (section_texts + quote_texts).join(" ")
  end
end
