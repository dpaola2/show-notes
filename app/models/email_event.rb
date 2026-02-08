class EmailEvent < ApplicationRecord
  belongs_to :user
  belongs_to :episode, optional: true

  validates :token, presence: true, uniqueness: true
  validates :event_type, presence: true, inclusion: { in: %w[open click] }
  validates :link_type, inclusion: { in: %w[summary listen] }, allow_nil: true
  validates :digest_date, presence: true

  scope :opens, -> { where(event_type: "open") }
  scope :clicks, -> { where(event_type: "click") }
  scope :triggered, -> { where.not(triggered_at: nil) }
  scope :for_date, ->(date) { where(digest_date: date.to_s) }

  def triggered?
    triggered_at.present?
  end

  def trigger!(request: nil)
    return if triggered?

    update!(
      triggered_at: Time.current,
      user_agent: request&.user_agent
    )
  end
end
