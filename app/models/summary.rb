class Summary < ApplicationRecord
  belongs_to :episode

  validates :sections, presence: true
  validate :quotes_is_array

  before_save :update_searchable_text

  private

  def quotes_is_array
    errors.add(:quotes, "must be an array") unless quotes.is_a?(Array)
  end

  # Extract text from jsonb sections for full-text search
  def update_searchable_text
    section_texts = (sections || []).map { |s| "#{s['title']} #{s['content']}" }
    quote_texts = (quotes || []).map { |q| q["text"] }
    self.searchable_text = (section_texts + quote_texts).join(" ")
  end
end
