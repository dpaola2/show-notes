desc "Seed test data for digest QA under library-drip: happy path, exhausted, mixed, NULL/tiebreak edges (idempotent, dev/test only)"
task seed_digest_qa: :environment do
  unless Rails.env.development? || Rails.env.test?
    abort "This task is only for development or test environments"
  end

  # --- User A: happy path — many eligible (digest_featured_at = nil) ---
  user_happy = User.find_or_create_by!(email: "digest-qa-happy@example.com") do |u|
    u.digest_enabled = true
  end
  user_happy.update!(digest_enabled: true)

  # --- User B: library-exhausted — every UserEpisode already featured ---
  user_exhausted = User.find_or_create_by!(email: "digest-qa-exhausted@example.com") do |u|
    u.digest_enabled = true
  end
  user_exhausted.update!(digest_enabled: true)

  # --- User C: mixed — some featured, some unfeatured ---
  user_mixed = User.find_or_create_by!(email: "digest-qa-mixed@example.com") do |u|
    u.digest_enabled = true
  end
  user_mixed.update!(digest_enabled: true)

  podcast_a = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/digest-qa-main") do |p|
    p.guid = "digest-qa-main"
    p.title = "The Daily Deep Dive"
  end

  podcast_b = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/digest-qa-secondary") do |p|
    p.guid = "digest-qa-secondary"
    p.title = "Tech Horizons"
  end

  [ user_happy, user_exhausted, user_mixed ].each do |u|
    u.subscriptions.find_or_create_by!(podcast: podcast_a)
    u.subscriptions.find_or_create_by!(podcast: podcast_b)
  end

  # --- Scenario A: 8 eligible episodes for happy-path user (digest_featured_at = nil) ---
  happy_specs = [
    { podcast: podcast_a, title: "Why Rust Is Eating the World", days_ago: 1 },
    { podcast: podcast_b, title: "The Future of Quantum Computing", days_ago: 2 },
    { podcast: podcast_a, title: "Building Products That Last", days_ago: 4 },
    { podcast: podcast_a, title: "The Art of Code Review", days_ago: 6 },
    { podcast: podcast_b, title: "AI and the Next Decade", days_ago: 8 },
    { podcast: podcast_a, title: "Database Design Patterns", days_ago: 10 },
    { podcast: podcast_b, title: "Remote Work Revolution", days_ago: 12 },
    { podcast: podcast_a, title: "Testing Strategies That Scale", days_ago: 14 }
  ]
  happy_specs.each_with_index do |spec, i|
    ep = qa_find_or_create_episode(spec[:podcast], "happy-#{i}", spec[:title], spec[:days_ago].days.ago)
    qa_find_or_create_user_episode(user_happy, ep, digest_featured_at: nil)
    qa_find_or_create_summary(ep, with_quotes: i < 6)
  end

  # --- Scenario B: 4 episodes for exhausted user — all already featured ---
  exhausted_specs = [
    { podcast: podcast_a, title: "Already Featured: The Lost Decade", days_ago: 30 },
    { podcast: podcast_b, title: "Already Featured: Why Async Won", days_ago: 45 },
    { podcast: podcast_a, title: "Already Featured: Cache Invalidation", days_ago: 60 },
    { podcast: podcast_b, title: "Already Featured: Monoliths Strike Back", days_ago: 75 }
  ]
  exhausted_specs.each_with_index do |spec, i|
    ep = qa_find_or_create_episode(spec[:podcast], "exhausted-#{i}", spec[:title], spec[:days_ago].days.ago)
    qa_find_or_create_user_episode(user_exhausted, ep, digest_featured_at: (i + 1).days.ago)
    qa_find_or_create_summary(ep, with_quotes: true)
  end

  # --- Scenario C: 6 episodes for mixed user — 3 featured, 3 unfeatured ---
  mixed_specs = [
    { podcast: podcast_a, title: "Mixed: Featured A", days_ago: 5,  featured_days_ago: 3 },
    { podcast: podcast_b, title: "Mixed: Featured B", days_ago: 7,  featured_days_ago: 5 },
    { podcast: podcast_a, title: "Mixed: Featured C", days_ago: 9,  featured_days_ago: 7 },
    { podcast: podcast_b, title: "Mixed: Unfeatured A", days_ago: 1, featured_days_ago: nil },
    { podcast: podcast_a, title: "Mixed: Unfeatured B", days_ago: 2, featured_days_ago: nil },
    { podcast: podcast_b, title: "Mixed: Unfeatured C", days_ago: 3, featured_days_ago: nil }
  ]
  mixed_specs.each_with_index do |spec, i|
    ep = qa_find_or_create_episode(spec[:podcast], "mixed-#{i}", spec[:title], spec[:days_ago].days.ago)
    featured_at = spec[:featured_days_ago] ? spec[:featured_days_ago].days.ago : nil
    qa_find_or_create_user_episode(user_mixed, ep, digest_featured_at: featured_at)
    qa_find_or_create_summary(ep, with_quotes: true)
  end

  # --- Edge: NULL published_at (sorts last per NULLS LAST) ---
  null_published_ep = qa_find_or_create_episode(podcast_a, "edge-null-published", "Edge: NULL published_at", nil)
  qa_find_or_create_user_episode(user_happy, null_published_ep, digest_featured_at: nil)
  qa_find_or_create_summary(null_published_ep, with_quotes: false)

  # --- Edge: identical published_at (id DESC tiebreak) ---
  tie_at = 20.days.ago
  tie_ep_1 = qa_find_or_create_episode(podcast_a, "edge-tie-1", "Edge: Tie A (lower id)", tie_at)
  tie_ep_2 = qa_find_or_create_episode(podcast_b, "edge-tie-2", "Edge: Tie B (higher id)", tie_at)
  qa_find_or_create_user_episode(user_happy, tie_ep_1, digest_featured_at: nil)
  qa_find_or_create_user_episode(user_happy, tie_ep_2, digest_featured_at: nil)
  qa_find_or_create_summary(tie_ep_1, with_quotes: true)
  qa_find_or_create_summary(tie_ep_2, with_quotes: true)

  happy_eligible = Episode.eligible_for_drip(user_happy).count
  exhausted_eligible = Episode.eligible_for_drip(user_exhausted).count
  mixed_eligible = Episode.eligible_for_drip(user_mixed).count

  puts
  puts "=== Digest QA Seed Summary (library-drip) ==="
  puts "Happy-path user:      #{user_happy.email}      (#{happy_eligible} eligible — incl. NULL-published + tiebreak edges)"
  puts "Exhausted user:       #{user_exhausted.email}  (#{exhausted_eligible} eligible — all already featured)"
  puts "Mixed user:           #{user_mixed.email}      (#{mixed_eligible} eligible — 3 featured, 3 unfeatured)"
  puts
  puts "=== Scenarios Created ==="
  puts "Happy path:           8 eligible UserEpisodes for #{user_happy.email}"
  puts "Library-exhausted:    4 already-featured UserEpisodes for #{user_exhausted.email} (next digest = NullMail)"
  puts "Mixed library:        3 featured + 3 unfeatured UserEpisodes for #{user_mixed.email}"
  puts "Edge NULL published:  1 UserEpisode (sorts last via NULLS LAST)"
  puts "Edge identical pub:   2 UserEpisodes share published_at (id DESC tiebreak)"
  puts
  puts "=== How to Preview ==="
  puts "1. SendDailyDigestJob.perform_now"
  puts "2. Open Letter Opener at /letter_opener"
  puts "3. Re-run this task — it is idempotent (no duplicate users/episodes/UserEpisodes)"
  puts
end

def qa_find_or_create_episode(podcast, slug, title, published_at)
  guid = "digest-qa-#{podcast.guid}-#{slug}"
  episode = Episode.find_or_initialize_by(guid: guid)
  episode.assign_attributes(
    podcast: podcast,
    title: title,
    audio_url: "https://audio.example.com/digest-qa/#{slug}.mp3",
    published_at: published_at,
    duration_seconds: 1800,
    description: "QA episode: #{title}"
  )
  episode.save!
  episode
end

def qa_find_or_create_user_episode(user, episode, digest_featured_at:)
  ue = UserEpisode.find_or_initialize_by(user: user, episode: episode)
  ue.assign_attributes(location: :library, processing_status: :ready)
  ue.save!
  # Stamp digest_featured_at directly (idempotent — only update if value differs).
  if ue.digest_featured_at != digest_featured_at
    ue.update_column(:digest_featured_at, digest_featured_at)
  end
  ue
end

def qa_find_or_create_summary(episode, with_quotes:)
  Summary.find_or_create_by!(episode: episode) do |s|
    s.sections = [
      {
        "title" => "Key Takeaways",
        "content" => "In this episode about #{episode.title.downcase}, we explore the most important " \
          "ideas shaping the industry today."
      },
      {
        "title" => "Deep Dive",
        "content" => "The hosts go beyond surface-level analysis to examine the underlying forces driving change."
      }
    ]
    s.quotes = if with_quotes
      [
        { "text" => "The best architectures emerge from teams that ship early and iterate relentlessly.", "start_time" => 420 },
        { "text" => "You cannot optimize what you do not measure.", "start_time" => 1380 }
      ]
    else
      []
    end
  end
end
