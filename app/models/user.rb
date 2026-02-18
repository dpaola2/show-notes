class User < ApplicationRecord
  has_many :subscriptions, dependent: :destroy
  has_many :podcasts, through: :subscriptions
  has_many :user_episodes, dependent: :destroy
  has_many :email_events, dependent: :destroy
  has_many :share_events, dependent: :nullify

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def generate_magic_token!
    update!(
      magic_token: SecureRandom.urlsafe_base64(32),
      magic_token_expires_at: 15.minutes.from_now
    )
    magic_token
  end

  def clear_magic_token!
    update!(magic_token: nil, magic_token_expires_at: nil)
  end

  def magic_token_valid?(token)
    magic_token.present? &&
      magic_token == token &&
      magic_token_expires_at&.future?
  end
end
