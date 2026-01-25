class Episode < ApplicationRecord
  belongs_to :podcast
  has_many :user_episodes, dependent: :destroy
  has_one :transcript, dependent: :destroy
  has_one :summary, dependent: :destroy

  validates :guid, presence: true, uniqueness: true
  validates :title, presence: true
  validates :audio_url, presence: true

  def estimated_cost_cents
    return 0 unless duration_seconds
    # AssemblyAI: $0.00065/second = 0.065 cents/second
    # Plus Claude summarization estimate: ~$0.01 per 1K tokens, roughly $0.10 per episode
    transcription_cost = (duration_seconds * 0.065).ceil
    summarization_cost = 10 # ~10 cents for Claude
    transcription_cost + summarization_cost
  end
end
