# NOTE: Filename intentionally retained as `library_scoped_processing_qa.rake` per GP-2
# decision (preserves `git log --follow` history). Body and operator-facing copy now
# reflect the library-drip data model (SN-17).

namespace :pipeline do
  desc "Seed test data for library-drip digest QA: happy/exhausted/mixed + NULL/tiebreak edges (idempotent, dev/test only)"
  task library_scoped_processing_qa: :environment do
    unless Rails.env.development? || Rails.env.test?
      abort "This task is only for development or test environments"
    end

    # --- Users ---
    user_happy = User.find_or_create_by!(email: "library-qa-happy@example.com") do |u|
      u.digest_enabled = true
    end
    user_happy.update!(digest_enabled: true)

    user_exhausted = User.find_or_create_by!(email: "library-qa-exhausted@example.com") do |u|
      u.digest_enabled = true
    end
    user_exhausted.update!(digest_enabled: true)

    user_mixed = User.find_or_create_by!(email: "library-qa-mixed@example.com") do |u|
      u.digest_enabled = true
    end
    user_mixed.update!(digest_enabled: true)

    # --- Podcasts ---
    podcast_a = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/library-qa-show-a") do |p|
      p.guid = "library-qa-show-a"
      p.title = "Library QA — Show A"
    end

    podcast_b = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/library-qa-show-b") do |p|
      p.guid = "library-qa-show-b"
      p.title = "Library QA — Show B"
    end

    [ user_happy, user_exhausted, user_mixed ].each do |u|
      u.subscriptions.find_or_create_by!(podcast: podcast_a)
      u.subscriptions.find_or_create_by!(podcast: podcast_b)
    end

    counts = {
      happy_eligible: 0,
      exhausted_already_featured: 0,
      mixed_eligible: 0,
      mixed_already_featured: 0,
      excluded: 0
    }

    # --- 1. Happy path: 6 library + ready + unfeatured episodes ---
    [
      [ podcast_a, "happy-1", "Show A — Happy 1", 1.day.ago ],
      [ podcast_a, "happy-2", "Show A — Happy 2", 2.days.ago ],
      [ podcast_b, "happy-3", "Show B — Happy 1", 3.days.ago ],
      [ podcast_a, "happy-4", "Show A — Happy 3", 5.days.ago ],
      [ podcast_b, "happy-5", "Show B — Happy 2", 7.days.ago ],
      [ podcast_b, "happy-6", "Show B — Happy 3", 9.days.ago ]
    ].each do |podcast, slug, title, published_at|
      ep = library_qa_find_or_create_episode(podcast, slug, title, published_at, with_summary: true)
      library_qa_find_or_create_user_episode(user_happy, ep, location: :library, processing_status: :ready, digest_featured_at: nil)
      counts[:happy_eligible] += 1
    end

    # --- 2. Exhausted: 4 episodes, all already featured ---
    [
      [ podcast_a, "exhausted-1", "Show A — Already Featured 1", 30.days.ago, 5.days.ago ],
      [ podcast_b, "exhausted-2", "Show B — Already Featured 1", 45.days.ago, 4.days.ago ],
      [ podcast_a, "exhausted-3", "Show A — Already Featured 2", 60.days.ago, 3.days.ago ],
      [ podcast_b, "exhausted-4", "Show B — Already Featured 2", 75.days.ago, 2.days.ago ]
    ].each do |podcast, slug, title, published_at, featured_at|
      ep = library_qa_find_or_create_episode(podcast, slug, title, published_at, with_summary: true)
      library_qa_find_or_create_user_episode(user_exhausted, ep, location: :library, processing_status: :ready, digest_featured_at: featured_at)
      counts[:exhausted_already_featured] += 1
    end

    # --- 3. Mixed: 4 episodes — 2 featured, 2 unfeatured ---
    mixed_ues = [
      [ podcast_a, "mixed-1", "Show A — Mixed Featured 1", 10.days.ago, 3.days.ago ],
      [ podcast_b, "mixed-2", "Show B — Mixed Featured 2", 12.days.ago, 4.days.ago ],
      [ podcast_a, "mixed-3", "Show A — Mixed Unfeatured 1", 1.day.ago, nil ],
      [ podcast_b, "mixed-4", "Show B — Mixed Unfeatured 2", 2.days.ago, nil ]
    ]
    mixed_ues.each do |podcast, slug, title, published_at, featured_at|
      ep = library_qa_find_or_create_episode(podcast, slug, title, published_at, with_summary: true)
      library_qa_find_or_create_user_episode(user_mixed, ep, location: :library, processing_status: :ready, digest_featured_at: featured_at)
      if featured_at.nil?
        counts[:mixed_eligible] += 1
      else
        counts[:mixed_already_featured] += 1
      end
    end

    # --- 4. Edge: NULL published_at ---
    null_pub_ep = library_qa_find_or_create_episode(podcast_a, "edge-null-published", "Edge: NULL published_at", nil, with_summary: true)
    library_qa_find_or_create_user_episode(user_happy, null_pub_ep, location: :library, processing_status: :ready, digest_featured_at: nil)
    counts[:happy_eligible] += 1

    # --- 5. Edge: identical published_at (id DESC tiebreak) ---
    tie_at = 20.days.ago
    tie_a = library_qa_find_or_create_episode(podcast_a, "edge-tie-1", "Edge: Tie A (lower id)", tie_at, with_summary: true)
    tie_b = library_qa_find_or_create_episode(podcast_b, "edge-tie-2", "Edge: Tie B (higher id)", tie_at, with_summary: true)
    library_qa_find_or_create_user_episode(user_happy, tie_a, location: :library, processing_status: :ready, digest_featured_at: nil)
    library_qa_find_or_create_user_episode(user_happy, tie_b, location: :library, processing_status: :ready, digest_featured_at: nil)
    counts[:happy_eligible] += 2

    # --- 6. Excluded variants (non-library, non-ready, archived) — should NOT appear in eligible_for_drip ---
    excluded_ep_pending = library_qa_find_or_create_episode(podcast_b, "excluded-pending", "Excluded: Library Pending", 1.hour.ago, with_summary: false)
    library_qa_find_or_create_user_episode(user_happy, excluded_ep_pending, location: :library, processing_status: :pending, digest_featured_at: nil)
    counts[:excluded] += 1

    excluded_ep_inbox = library_qa_find_or_create_episode(podcast_a, "excluded-inbox", "Excluded: Inbox", 1.hour.ago, with_summary: true)
    library_qa_find_or_create_user_episode(user_happy, excluded_ep_inbox, location: :inbox, processing_status: :pending, digest_featured_at: nil)
    counts[:excluded] += 1

    excluded_ep_archive = library_qa_find_or_create_episode(podcast_b, "excluded-archive", "Excluded: Archived", 1.hour.ago, with_summary: true)
    library_qa_find_or_create_user_episode(user_happy, excluded_ep_archive, location: :archive, processing_status: :ready, digest_featured_at: nil)
    counts[:excluded] += 1

    happy_eligible = Episode.eligible_for_drip(user_happy).count
    exhausted_eligible = Episode.eligible_for_drip(user_exhausted).count
    mixed_eligible = Episode.eligible_for_drip(user_mixed).count

    puts
    puts "=== Library-Drip QA Seed Summary ==="
    puts "Happy-path user:    #{user_happy.email}      (#{happy_eligible} eligible — incl. NULL-published + tiebreak edges)"
    puts "Exhausted user:     #{user_exhausted.email}  (#{exhausted_eligible} eligible — all already featured, expect NullMail)"
    puts "Mixed user:         #{user_mixed.email}      (#{mixed_eligible} eligible — half already featured)"
    puts
    puts "=== Episodes by scenario (created/updated) ==="
    puts "Happy eligible:           #{counts[:happy_eligible]}"
    puts "Exhausted already-featured: #{counts[:exhausted_already_featured]}"
    puts "Mixed eligible:           #{counts[:mixed_eligible]}"
    puts "Mixed already-featured:   #{counts[:mixed_already_featured]}"
    puts "Excluded variants:        #{counts[:excluded]}  (non-library or non-ready — must NOT appear)"
    puts
    puts "=== QA Scenarios ==="
    puts "1. Run: SendDailyDigestJob.perform_now"
    puts "2. Check letter_opener — happy + mixed users get a digest; exhausted user does NOT"
    puts "3. Verify featured + 5 compact for happy user, sorted by published_at DESC NULLS LAST, id DESC"
    puts "4. Verify NULL-published episode appears LAST in compact (NULLS LAST)"
    puts "5. Verify identical-published_at pair tiebroken by id DESC (deterministic across runs)"
    puts "6. Re-run this task — idempotent (no duplicate users/podcasts/UserEpisodes)"
    puts
  end
end

def library_qa_find_or_create_episode(podcast, slug, title, published_at, with_summary: false)
  guid = "#{podcast.feed_url}/#{slug}"
  episode = Episode.find_or_initialize_by(guid: guid)
  episode.assign_attributes(
    podcast: podcast,
    title: title,
    audio_url: "https://audio.example.com/library-qa/#{slug}.mp3",
    published_at: published_at,
    duration_seconds: 1800,
    description: "QA episode: #{title}"
  )
  episode.save!

  if with_summary
    Transcript.find_or_create_by!(episode: episode) do |t|
      t.content = "Sample transcript for #{title}."
    end
    Summary.find_or_create_by!(episode: episode) do |s|
      s.sections = [ { "title" => "Summary", "content" => "Summary for #{title}. Covers the main topics discussed." } ]
      s.quotes = []
    end
  end

  episode
end

def library_qa_find_or_create_user_episode(user, episode, location:, processing_status:, digest_featured_at:)
  ue = UserEpisode.find_or_initialize_by(user: user, episode: episode)
  ue.assign_attributes(location: location, processing_status: processing_status)
  ue.save!
  if ue.digest_featured_at != digest_featured_at
    ue.update_column(:digest_featured_at, digest_featured_at)
  end
  ue
end
