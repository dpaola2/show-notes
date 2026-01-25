class UserEpisode < ApplicationRecord
  belongs_to :user
  belongs_to :episode

  enum :location, { inbox: 0, library: 1, archive: 2, trash: 3 }
  enum :processing_status, {
    pending: 0,
    downloading: 1,
    transcribing: 2,
    summarizing: 3,
    ready: 4,
    error: 5
  }

  validates :user_id, uniqueness: { scope: :episode_id }

  scope :in_inbox, -> { where(location: :inbox) }
  scope :in_library, -> { where(location: :library) }
  scope :in_archive, -> { where(location: :archive) }
  scope :in_trash, -> { where(location: :trash) }
  scope :expired_trash, -> { in_trash.where("trashed_at < ?", 90.days.ago) }

  # Delegate common episode attributes for convenience
  delegate :title, :description, :audio_url, :duration_seconds, :published_at,
           :podcast, :transcript, :summary, :estimated_cost_cents, to: :episode

  def move_to_library!
    update!(
      location: :library,
      processing_status: :pending,
      trashed_at: nil,
      retry_count: 0,
      next_retry_at: nil,
      processing_error: nil
    )
  end

  def move_to_inbox!
    update!(location: :inbox, trashed_at: nil)
  end

  def move_to_archive!
    update!(location: :archive, trashed_at: nil)
  end

  def move_to_trash!
    update!(location: :trash, trashed_at: Time.current)
  end
end
