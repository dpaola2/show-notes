desc "Seed test data for onboarding/digest QA under library-drip: full library spread, edges, idempotent (dev/test only)"
task qa_seed: :environment do
  unless Rails.env.development? || Rails.env.test?
    abort "This task is only for development or test environments"
  end

  # --- Primary user — happy path with a sizable library ---
  primary = User.find_or_create_by!(email: "onboarding-qa@example.com") do |u|
    u.digest_enabled = true
  end
  primary.update!(digest_enabled: true)

  # --- Empty user — has subscriptions but every UE is featured (digest = NullMail) ---
  empty_user = User.find_or_create_by!(email: "onboarding-empty@example.com") do |u|
    u.digest_enabled = true
  end
  empty_user.update!(digest_enabled: true)

  # --- Disabled user — digest_enabled = false ---
  disabled_user = User.find_or_create_by!(email: "onboarding-disabled@example.com") do |u|
    u.digest_enabled = false
  end
  disabled_user.update!(digest_enabled: false)

  # --- Mixed user — some featured, some not ---
  mixed_user = User.find_or_create_by!(email: "onboarding-mixed@example.com") do |u|
    u.digest_enabled = true
  end
  mixed_user.update!(digest_enabled: true)

  podcast_data = [
    { title: "Build Your SaaS",     feed_url: "https://feeds.example.com/build-your-saas",   episodes: 6 },
    { title: "Acquired",            feed_url: "https://feeds.example.com/acquired-pod",       episodes: 8 },
    { title: "Changelog",           feed_url: "https://feeds.example.com/changelog",          episodes: 3 },
    { title: "Software Engineering Daily", feed_url: "https://feeds.example.com/se-daily",    episodes: 5 },
    { title: "Empty Show",          feed_url: "https://feeds.example.com/empty-show",         episodes: 2 }
  ]

  total_eligible = 0

  podcast_data.each do |pd|
    podcast = Podcast.find_or_create_by!(feed_url: pd[:feed_url]) do |p|
      p.guid = pd[:feed_url]
      p.title = pd[:title]
    end
    podcast.update!(title: pd[:title])

    [ primary, empty_user, mixed_user ].each do |u|
      u.subscriptions.find_or_create_by!(podcast: podcast)
    end

    pd[:episodes].times do |i|
      slug = "ep-#{i + 1}"
      published_at = (i + 1).days.ago

      ep = qa_seed_find_or_create_episode(podcast, slug, "#{pd[:title]} — Episode #{i + 1}", published_at)
      qa_seed_find_or_create_summary(ep, ep_index: i + 1)

      # Primary: every UE eligible (digest_featured_at = nil)
      qa_seed_find_or_create_user_episode(primary, ep, digest_featured_at: nil)
      total_eligible += 1

      # Empty user: every UE already featured (exhausted scenario)
      qa_seed_find_or_create_user_episode(empty_user, ep, digest_featured_at: (i + 1).days.ago)

      # Mixed user: alternate featured/unfeatured for predictable mixed scenario
      mixed_at = i.even? ? (i + 1).days.ago : nil
      qa_seed_find_or_create_user_episode(mixed_user, ep, digest_featured_at: mixed_at)
    end
  end

  # --- Edge: Episode with NULL published_at (sorts last under NULLS LAST) ---
  edge_podcast = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/qa-edge-podcast") do |p|
    p.guid = "qa-edge-podcast"
    p.title = "QA Edges Show"
  end
  primary.subscriptions.find_or_create_by!(podcast: edge_podcast)

  null_pub_ep = qa_seed_find_or_create_episode(edge_podcast, "edge-null-published", "Edge: NULL published_at", nil)
  qa_seed_find_or_create_summary(null_pub_ep, ep_index: 1)
  qa_seed_find_or_create_user_episode(primary, null_pub_ep, digest_featured_at: nil)

  # --- Edge: identical published_at (id DESC tiebreak) ---
  tie_at = 50.days.ago
  tie_a = qa_seed_find_or_create_episode(edge_podcast, "edge-tie-a", "Edge: Tie A", tie_at)
  tie_b = qa_seed_find_or_create_episode(edge_podcast, "edge-tie-b", "Edge: Tie B", tie_at)
  qa_seed_find_or_create_summary(tie_a, ep_index: 99)
  qa_seed_find_or_create_summary(tie_b, ep_index: 100)
  qa_seed_find_or_create_user_episode(primary, tie_a, digest_featured_at: nil)
  qa_seed_find_or_create_user_episode(primary, tie_b, digest_featured_at: nil)

  primary_eligible = Episode.eligible_for_drip(primary).count
  empty_eligible = Episode.eligible_for_drip(empty_user).count
  mixed_eligible = Episode.eligible_for_drip(mixed_user).count

  puts
  puts "=== QA Seed Summary (library-drip) ==="
  puts "Primary user:    #{primary.email}      (#{primary_eligible} eligible — happy path)"
  puts "Empty user:      #{empty_user.email}   (#{empty_eligible} eligible — exhausted, expect NullMail)"
  puts "Disabled user:   #{disabled_user.email} (digest_enabled = false — expect skip)"
  puts "Mixed user:      #{mixed_user.email}   (#{mixed_eligible} eligible — half already featured)"
  puts
  puts "=== Scenarios Created ==="
  puts "Happy path:           Primary user has #{primary_eligible} unfeatured library UserEpisodes"
  puts "Library-exhausted:    Empty user has all UserEpisodes already featured"
  puts "Mixed library:        Mixed user has alternating featured/unfeatured UEs"
  puts "Edge NULL published:  1 UserEpisode with NULL published_at (sorts last)"
  puts "Edge identical pub:   2 UserEpisodes share published_at (id DESC tiebreak)"
  puts "digest_enabled false: Disabled user is skipped by SendDailyDigestJob"
  puts
  puts "=== How to Preview ==="
  puts "1. SendDailyDigestJob.perform_now"
  puts "2. Open Letter Opener at /letter_opener — primary + mixed users get a digest, empty + disabled do not"
  puts "3. Re-run this task — it is idempotent (no duplicate users/podcasts/UserEpisodes)"
  puts
end

def qa_seed_find_or_create_episode(podcast, slug, title, published_at)
  guid = "#{podcast.feed_url}/#{slug}"
  episode = Episode.find_or_initialize_by(guid: guid)
  episode.assign_attributes(
    podcast: podcast,
    title: title,
    audio_url: "https://audio.example.com/qa-seed/#{slug}.mp3",
    published_at: published_at,
    duration_seconds: 1800,
    description: "QA episode: #{title}"
  )
  episode.save!
  episode
end

def qa_seed_find_or_create_user_episode(user, episode, digest_featured_at:)
  ue = UserEpisode.find_or_initialize_by(user: user, episode: episode)
  ue.assign_attributes(location: :library, processing_status: :ready)
  ue.save!
  if ue.digest_featured_at != digest_featured_at
    ue.update_column(:digest_featured_at, digest_featured_at)
  end
  ue
end

def qa_seed_find_or_create_summary(episode, ep_index:)
  Summary.find_or_create_by!(episode: episode) do |s|
    s.sections = [
      {
        "title" => "Introduction",
        "content" => "Episode #{ep_index} of #{episode.podcast.title} dives into the latest developments in the field."
      },
      {
        "title" => "Main Discussion",
        "content" => "The hosts explore practical strategies and real-world examples that listeners can apply."
      }
    ]
    s.quotes = if ep_index % 3 == 0
      []
    else
      [
        { "text" => "The best time to ship was yesterday. The second best time is right now.", "start_time" => 300 + (ep_index * 10) },
        { "text" => "You don't need a perfect architecture. You need a working product.", "start_time" => 900 + (ep_index * 15) }
      ]
    end
  end
end
