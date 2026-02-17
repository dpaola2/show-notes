namespace :pipeline do
  desc "Seed test data for library-scoped processing QA (idempotent, dev only)"
  task library_scoped_processing_qa: :environment do
    unless Rails.env.development?
      abort "This task is only for development environments"
    end

    test_email = "library-qa@example.com"

    # --- Test user ---
    user = User.find_or_create_by!(email: test_email) do |u|
      u.digest_enabled = true
    end
    user.update!(digest_enabled: true, digest_sent_at: 25.hours.ago)

    puts "Test user: #{user.email} (digest_sent_at: #{user.digest_sent_at})"

    # --- Podcasts ---
    podcast_a = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/library-qa-show-a") do |p|
      p.guid = "library-qa-show-a"
      p.title = "Library QA — Show A"
    end

    podcast_b = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/library-qa-show-b") do |p|
      p.guid = "library-qa-show-b"
      p.title = "Library QA — Show B"
    end

    user.subscriptions.find_or_create_by!(podcast: podcast_a)
    user.subscriptions.find_or_create_by!(podcast: podcast_b)

    counts = { inbox: 0, library_ready: 0, library_pending: 0, library_error: 0, archived: 0, old_library: 0 }

    # --- Helper to create episode + user_episode ---
    create_ep = lambda do |podcast, guid_suffix, title, location:, processing_status:, updated_at: Time.current, with_summary: false|
      guid = "#{podcast.feed_url}/#{guid_suffix}"
      episode = Episode.find_or_initialize_by(guid: guid)
      episode.assign_attributes(
        podcast: podcast,
        title: title,
        audio_url: "https://audio.example.com/#{guid_suffix}.mp3",
        published_at: 2.hours.ago,
        duration_seconds: 1800,
        description: "QA episode: #{title}"
      )
      episode.save!

      ue = UserEpisode.find_or_initialize_by(user: user, episode: episode)
      ue.assign_attributes(location: location, processing_status: processing_status)
      ue.save!
      ue.update_column(:updated_at, updated_at)

      if with_summary
        Transcript.find_or_create_by!(episode: episode) do |t|
          t.content = "Sample transcript for #{title}."
        end
        unless episode.summary
          Summary.create!(
            episode: episode,
            sections: [{ "title" => "Summary", "content" => "This is the summary for #{title}. It covers the main topics discussed." }],
            quotes: []
          )
        end
      end

      episode
    end

    # --- 1. Library + ready + recent (SHOULD appear in digest) ---
    create_ep.call(podcast_a, "lib-ready-1", "Show A — Ready Recent 1",
      location: :library, processing_status: :ready, updated_at: 2.hours.ago, with_summary: true)
    create_ep.call(podcast_a, "lib-ready-2", "Show A — Ready Recent 2",
      location: :library, processing_status: :ready, updated_at: 6.hours.ago, with_summary: true)
    create_ep.call(podcast_b, "lib-ready-3", "Show B — Ready Recent 1",
      location: :library, processing_status: :ready, updated_at: 1.hour.ago, with_summary: true)
    counts[:library_ready] = 3

    # --- 2. Library + ready + OLD (should NOT appear — 24-hour cap) ---
    create_ep.call(podcast_a, "lib-ready-old", "Show A — Ready But Old (>24h)",
      location: :library, processing_status: :ready, updated_at: 26.hours.ago, with_summary: true)
    counts[:old_library] = 1

    # --- 3. Library + pending (should NOT appear in digest) ---
    create_ep.call(podcast_b, "lib-pending-1", "Show B — Pending Processing",
      location: :library, processing_status: :pending)
    counts[:library_pending] = 1

    # --- 4. Library + error (should NOT appear in digest) ---
    create_ep.call(podcast_a, "lib-error-1", "Show A — Error Processing",
      location: :library, processing_status: :error)
    counts[:library_error] = 1

    # --- 5. Inbox only (should NOT appear in digest) ---
    create_ep.call(podcast_a, "inbox-1", "Show A — Inbox Episode",
      location: :inbox, processing_status: :pending)
    create_ep.call(podcast_b, "inbox-2", "Show B — Inbox Episode",
      location: :inbox, processing_status: :pending)
    counts[:inbox] = 2

    # --- 6. Archived (should NOT appear in digest) ---
    create_ep.call(podcast_b, "archived-1", "Show B — Archived Episode",
      location: :archive, processing_status: :ready, with_summary: true)
    counts[:archived] = 1

    # --- Summary ---
    puts
    puts "=== Library-Scoped Processing QA Seed Summary ==="
    puts "User:                #{user.email} (digest_enabled: true, digest_sent_at: #{user.digest_sent_at})"
    puts "Podcasts:            #{podcast_a.title}, #{podcast_b.title}"
    puts
    puts "Episodes by state:"
    puts "  Library + ready (recent):  #{counts[:library_ready]}  <-- SHOULD appear in digest"
    puts "  Library + ready (old >24h): #{counts[:old_library]}  <-- should NOT appear (24-hour cap)"
    puts "  Library + pending:         #{counts[:library_pending]}  <-- should NOT appear"
    puts "  Library + error:           #{counts[:library_error]}  <-- should NOT appear"
    puts "  Inbox only:                #{counts[:inbox]}  <-- should NOT appear"
    puts "  Archived:                  #{counts[:archived]}  <-- should NOT appear"
    puts
    puts "=== QA Scenarios ==="
    puts "1. Run: SendDailyDigestJob.perform_now"
    puts "2. Check letter_opener — only #{counts[:library_ready]} episodes should appear"
    puts "3. Subject should read: \"Your library — #{counts[:library_ready]} episodes ready\""
    puts "4. Verify old (>24h), pending, error, inbox, and archived episodes are absent"
    puts "5. Verify episodes grouped by show (Show A, Show B)"
    puts
  end
end
