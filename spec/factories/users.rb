FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    magic_token { nil }
    magic_token_expires_at { nil }

    trait :with_magic_token do
      magic_token { SecureRandom.urlsafe_base64(32) }
      magic_token_expires_at { 15.minutes.from_now }
    end

    trait :with_expired_token do
      magic_token { SecureRandom.urlsafe_base64(32) }
      magic_token_expires_at { 1.hour.ago }
    end
  end
end
