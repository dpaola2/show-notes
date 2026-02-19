class ShareEvent < ApplicationRecord
  belongs_to :episode
  belongs_to :user, optional: true

  validates :share_target, presence: true,
            inclusion: { in: %w[clipboard twitter linkedin native] }

  scope :for_episode, ->(episode) { where(episode: episode) }
  scope :by_target, ->(target) { where(share_target: target) }
end
