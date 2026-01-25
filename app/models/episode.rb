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
    minutes = (duration_seconds / 60.0).ceil
    (minutes * 0.6).ceil  # $0.006/min = 0.6 cents/min for Whisper
  end
end
