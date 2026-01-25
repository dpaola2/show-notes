FactoryBot.define do
  factory :episode do
    podcast
    guid { Faker::Internet.unique.uuid }
    title { Faker::Lorem.sentence(word_count: 5) }
    description { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    audio_url { Faker::Internet.url(path: "/episode.mp3") }
    duration_seconds { rand(1800..7200) }  # 30 min to 2 hours
    published_at { Faker::Time.backward(days: 30) }
  end
end
