FactoryBot.define do
  factory :share_event do
    episode
    user { nil }
    share_target { "clipboard" }
    user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }
    referrer { nil }

    trait :clipboard do
      share_target { "clipboard" }
    end

    trait :twitter do
      share_target { "twitter" }
    end

    trait :linkedin do
      share_target { "linkedin" }
    end

    trait :native do
      share_target { "native" }
    end

    trait :with_user do
      user
    end
  end
end
