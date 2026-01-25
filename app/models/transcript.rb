class Transcript < ApplicationRecord
  belongs_to :episode

  validates :content, presence: true
end
