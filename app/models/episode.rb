class Episode < ApplicationRecord
  belongs_to :podcast
  has_many :user_episodes, dependent: :destroy
  has_one :transcript, dependent: :destroy
  has_one :summary, dependent: :destroy
  has_many :email_events, dependent: :destroy
  has_many :share_events, dependent: :destroy
  has_one_attached :og_image

  enum :processing_status, {
    pending: 0,
    downloading: 1,
    transcribing: 2,
    summarizing: 3,
    ready: 4,
    error: 5
  }

  scope :library_ready_since, ->(user, since) {
    joins(:user_episodes, :podcast)
      .where(user_episodes: { user_id: user.id, location: :library, processing_status: :ready })
      .where("user_episodes.updated_at > ?", since)
      .includes(:podcast, :summary)
      .order("podcasts.title ASC, episodes.published_at DESC")
  }

  validates :guid, presence: true, uniqueness: { scope: :podcast_id }
  validates :title, presence: true
  validates :audio_url, presence: true

  def og_image_url
    return nil unless og_image.attached?
    host = Rails.application.routes.default_url_options[:host] || ENV.fetch("APP_HOST", "localhost:3000")
    Rails.application.routes.url_helpers.rails_blob_url(og_image, host: host)
  end

  def shareable?
    summary.present?
  end

  def estimated_cost_cents
    return 0 unless duration_seconds
    # AssemblyAI: $0.00065/second = 0.065 cents/second
    # Plus Claude summarization estimate: ~$0.01 per 1K tokens, roughly $0.10 per episode
    transcription_cost = (duration_seconds * 0.065).ceil
    summarization_cost = 10 # ~10 cents for Claude
    transcription_cost + summarization_cost
  end
end
