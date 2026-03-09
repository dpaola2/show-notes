FactoryBot.define do
  factory :api_token do
    user
    token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
    last_used_at { nil }
  end
end
