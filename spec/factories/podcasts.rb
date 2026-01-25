FactoryBot.define do
  factory :podcast do
    guid { Faker::Internet.unique.uuid }
    title { Faker::Lorem.sentence(word_count: 3) }
    author { Faker::Name.name }
    description { Faker::Lorem.paragraph }
    feed_url { Faker::Internet.url }
    artwork_url { Faker::Internet.url(path: "/artwork.jpg") }
    last_fetched_at { nil }
  end
end
