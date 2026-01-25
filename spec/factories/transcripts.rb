FactoryBot.define do
  factory :transcript do
    episode
    content do
      {
        segments: [
          { start: 0.0, end: 10.5, text: "Welcome to the show." },
          { start: 10.5, end: 25.0, text: "Today we're going to talk about something interesting." },
          { start: 25.0, end: 45.0, text: "Let me introduce our guest." }
        ]
      }.to_json
    end
  end
end
