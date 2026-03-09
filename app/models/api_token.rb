class ApiToken < ApplicationRecord
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true

  # Generate a new token. Returns the ApiToken and the plaintext token (only time it's visible).
  # Stores only the SHA-256 digest in the database.
  def self.generate_for(user)
    plaintext = SecureRandom.urlsafe_base64(32)
    token = user.api_tokens.create!(token_digest: Digest::SHA256.hexdigest(plaintext))
    [token, plaintext]
  end

  # Look up a token by its plaintext value (hashes and queries).
  def self.find_by_plaintext(plaintext)
    return nil if plaintext.blank?
    find_by(token_digest: Digest::SHA256.hexdigest(plaintext))
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end
end
