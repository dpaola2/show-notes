FactoryBot.define do
  factory :email_event do
    user
    token { SecureRandom.urlsafe_base64(16) }
    event_type { "click" }
    link_type { "summary" }
    episode
    digest_date { Date.current.to_s }
    triggered_at { nil }
    user_agent { nil }

    trait :open do
      event_type { "open" }
      link_type { nil }
      episode { nil }
    end

    trait :click_summary do
      event_type { "click" }
      link_type { "summary" }
    end

    trait :click_listen do
      event_type { "click" }
      link_type { "listen" }
    end

    trait :triggered do
      triggered_at { Time.current }
      user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }
    end
  end
end
