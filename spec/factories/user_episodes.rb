FactoryBot.define do
  factory :user_episode do
    user
    episode
    location { :inbox }
    trashed_at { nil }
    processing_status { :pending }
    processing_error { nil }

    trait :in_library do
      location { :library }
    end

    trait :in_archive do
      location { :archive }
    end

    trait :in_trash do
      location { :trash }
      trashed_at { Time.current }
    end

    trait :ready do
      location { :library }
      processing_status { :ready }
    end

    trait :processing do
      location { :library }
      processing_status { :transcribing }
    end

    trait :with_error do
      location { :library }
      processing_status { :error }
      processing_error { "Failed to download audio file" }
    end
  end
end
