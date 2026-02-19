namespace :digest do
  desc "Seed test data for digest QA: featured episode layout, edge cases, all scenarios (idempotent, dev only)"
  task seed_qa: :environment do
    unless Rails.env.development?
      abort "This task is only for development environments"
    end

    test_email = "digest-qa@example.com"

    # --- Test user ---
    user = User.find_or_create_by!(email: test_email) do |u|
      u.digest_enabled = true
    end
    user.update!(digest_enabled: true, digest_sent_at: 25.hours.ago)
    token = user.generate_magic_token!

    puts "Test user: #{user.email} (id: #{user.id})"

    # --- Scenario A: 8 episodes with summaries (tests featured + full recent + overflow) ---
    podcast_a = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/digest-qa-main") do |p|
      p.guid = "digest-qa-main"
      p.title = "The Daily Deep Dive"
    end
    user.subscriptions.find_or_create_by!(podcast: podcast_a)

    podcast_b = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/digest-qa-secondary") do |p|
      p.guid = "digest-qa-secondary"
      p.title = "Tech Horizons"
    end
    user.subscriptions.find_or_create_by!(podcast: podcast_b)

    scenario_a_episodes = []
    # 5 episodes from podcast A, 3 from podcast B — all with summaries
    [
      { podcast: podcast_a, title: "Why Rust Is Eating the World", hours_ago: 1 },
      { podcast: podcast_b, title: "The Future of Quantum Computing", hours_ago: 2 },
      { podcast: podcast_a, title: "Building Products That Last", hours_ago: 4 },
      { podcast: podcast_a, title: "The Art of Code Review", hours_ago: 6 },
      { podcast: podcast_b, title: "AI and the Next Decade", hours_ago: 8 },
      { podcast: podcast_a, title: "Database Design Patterns", hours_ago: 10 },
      { podcast: podcast_b, title: "Remote Work Revolution", hours_ago: 12 },
      { podcast: podcast_a, title: "Testing Strategies That Scale", hours_ago: 14 }
    ].each_with_index do |data, i|
      ep = create_qa_episode(data[:podcast], data[:title], i)
      ue = create_qa_user_episode(user, ep, data[:hours_ago])
      create_qa_summary(ep, with_quotes: i < 6) # Last 2 episodes have no quotes
      scenario_a_episodes << ep
    end

    # --- Scenario B: Single-episode podcast (tests single-episode digest case) ---
    podcast_c = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/digest-qa-single") do |p|
      p.guid = "digest-qa-single"
      p.title = "One-Off Interviews"
    end
    # No subscription for primary user — use a second user for this scenario
    single_user = User.find_or_create_by!(email: "digest-qa-single@example.com") do |u|
      u.digest_enabled = true
    end
    single_user.update!(digest_enabled: true, digest_sent_at: 25.hours.ago)
    single_user.subscriptions.find_or_create_by!(podcast: podcast_c)

    single_ep = create_qa_episode(podcast_c, "The One Big Idea", 100)
    create_qa_user_episode(single_user, single_ep, 3)
    create_qa_summary(single_ep, with_quotes: true)

    # --- Scenario C: Episodes without summaries (tests exclusion from digest) ---
    no_summary_eps = []
    2.times do |i|
      ep = create_qa_episode(podcast_a, "Unprocessed Episode #{i + 1}", 200 + i)
      create_qa_user_episode(user, ep, 3 + i)
      # No summary created — should be excluded from digest
      no_summary_eps << ep
    end

    # --- Scenario D: Episode with empty quotes array (tests no-quotes edge case) ---
    empty_quotes_ep = create_qa_episode(podcast_b, "The Silent Revolution", 300)
    create_qa_user_episode(user, empty_quotes_ep, 5)
    Summary.find_or_create_by!(episode: empty_quotes_ep) do |s|
      s.sections = [
        { "title" => "Overview", "content" => "A deep look at how quiet changes reshape industries without anyone noticing until it is too late." },
        { "title" => "Key Insights", "content" => "The most impactful shifts happen gradually. By the time they are obvious, the early movers have already won." }
      ]
      s.quotes = []
    end

    # --- Summary ---
    main_digest_count = Episode.library_ready_since(user, user.digest_sent_at).count
    single_digest_count = Episode.library_ready_since(single_user, single_user.digest_sent_at).count

    puts
    puts "=== Digest QA Seed Summary ==="
    puts "Primary user:        #{user.email} (#{main_digest_count} episodes in digest)"
    puts "Single-episode user: #{single_user.email} (#{single_digest_count} episode in digest)"
    puts "Magic link:          /auth/verify?token=#{token}"
    puts "  (expires in 15 minutes — re-run task to refresh)"
    puts
    puts "=== Scenarios Created ==="
    puts "A) Featured + overflow: #{scenario_a_episodes.size} episodes with summaries across 2 podcasts"
    puts "   → Digest shows 1 featured + 5 recent, 2 overflow omitted"
    puts "B) Single episode:      1 episode for #{single_user.email}"
    puts "   → Digest shows featured only, no 'Latest episodes' section"
    puts "C) No summaries:        #{no_summary_eps.size} episodes without summaries"
    puts "   → Excluded from digest entirely"
    puts "D) Empty quotes:        '#{empty_quotes_ep.title}' has quotes: []"
    puts "   → No quotes block rendered"
    puts
    puts "=== How to Preview ==="
    puts "1. Log in: /auth/verify?token=#{token}"
    puts "2. Run: DigestMailer.daily_digest(User.find_by(email: '#{user.email}')).deliver_now"
    puts "3. Open Letter Opener at /letter_opener to view the digest"
    puts "4. For single-episode: DigestMailer.daily_digest(User.find_by(email: '#{single_user.email}')).deliver_now"
    puts
  end
end

def create_qa_episode(podcast, title, index)
  guid = "digest-qa-#{podcast.guid}-#{index}"
  episode = podcast.episodes.find_or_initialize_by(guid: guid)
  episode.assign_attributes(
    title: title,
    audio_url: "https://audio.example.com/digest-qa/#{index}.mp3",
    published_at: (index + 1).days.ago,
    duration_seconds: rand(1200..5400),
    description: "QA episode: #{title}"
  )
  episode.save!
  episode
end

def create_qa_user_episode(user, episode, hours_ago)
  ue = UserEpisode.find_or_initialize_by(user: user, episode: episode)
  ue.assign_attributes(location: :library, processing_status: :ready)
  ue.save!
  ue.update_column(:updated_at, hours_ago.hours.ago)
  ue
end

def create_qa_summary(episode, with_quotes: true)
  Summary.find_or_create_by!(episode: episode) do |s|
    s.sections = [
      {
        "title" => "Key Takeaways",
        "content" => "In this episode about #{episode.title.downcase}, we explore the most important " \
          "ideas shaping the industry today. The conversation covers practical strategies " \
          "and real-world examples that listeners can apply immediately."
      },
      {
        "title" => "Deep Dive",
        "content" => "The hosts go beyond surface-level analysis to examine the underlying forces " \
          "driving change. They discuss trade-offs, second-order effects, and the lessons " \
          "learned from teams that have navigated similar challenges successfully."
      },
      {
        "title" => "Looking Ahead",
        "content" => "What does the future hold? The episode concludes with predictions and " \
          "actionable advice for anyone looking to stay ahead of the curve in this " \
          "rapidly evolving landscape."
      }
    ]
    s.quotes = if with_quotes
      [
        { "text" => "The best architectures emerge from teams that ship early and iterate relentlessly.", "start_time" => 420 },
        { "text" => "You cannot optimize what you do not measure, but not everything that matters can be measured.", "start_time" => 1380 }
      ]
    else
      []
    end
  end
end
