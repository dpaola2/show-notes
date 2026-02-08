namespace :onboarding do
  desc "Seed test data for onboarding QA: podcasts, episodes, summaries, tracking events (idempotent, dev only)"
  task seed: :environment do
    unless Rails.env.development?
      abort "This task is only for development environments"
    end

    test_email = "onboarding-qa@example.com"

    # --- Test user ---
    user = User.find_or_create_by!(email: test_email) do |u|
      u.digest_enabled = true
    end
    user.update!(digest_enabled: true, digest_sent_at: 25.hours.ago)
    token = user.generate_magic_token!

    puts "Test user: #{user.email} (id: #{user.id})"

    # --- Podcast definitions ---
    podcast_data = [
      {
        title: "Build Your SaaS",
        feed_url: "https://feeds.example.com/build-your-saas",
        episodes: 8, # Mix of ready and pending
        ready_count: 6
      },
      {
        title: "Acquired",
        feed_url: "https://feeds.example.com/acquired-pod",
        episodes: 15, # Large show — many episodes
        ready_count: 12
      },
      {
        title: "Changelog",
        feed_url: "https://feeds.example.com/changelog",
        episodes: 5,
        ready_count: 3
      },
      {
        title: "Software Engineering Daily",
        feed_url: "https://feeds.example.com/se-daily",
        episodes: 10,
        ready_count: 8
      },
      {
        title: "Empty Show (No New Episodes)",
        feed_url: "https://feeds.example.com/empty-show",
        episodes: 2, # Old episodes only — tests empty digest scenario
        ready_count: 2,
        all_old: true
      }
    ]

    total_episodes = 0
    ready_episodes = 0
    pending_episodes = 0

    podcast_data.each do |pd|
      podcast = Podcast.find_or_create_by!(feed_url: pd[:feed_url]) do |p|
        p.guid = pd[:feed_url]
        p.title = pd[:title]
      end
      podcast.update!(title: pd[:title])

      user.subscriptions.find_or_create_by!(podcast: podcast)

      pd[:episodes].times do |i|
        ep_num = i + 1
        guid = "#{podcast.feed_url}/ep-#{ep_num}"

        base_time = pd[:all_old] ? 3.days.ago : 1.hour.ago
        published_at = base_time - (i * 2).hours

        episode = Episode.find_or_initialize_by(guid: guid)
        episode.assign_attributes(
          podcast: podcast,
          title: "#{pd[:title]} — Episode #{ep_num}",
          audio_url: "https://audio.example.com/#{podcast.feed_url.split('/').last}/ep-#{ep_num}.mp3",
          published_at: published_at,
          duration_seconds: rand(1200..5400),
          description: "Episode #{ep_num} of #{pd[:title]}. A sample episode for QA testing.",
          created_at: published_at
        )
        episode.save!

        is_ready = ep_num <= pd[:ready_count]

        if is_ready
          # Create transcript
          Transcript.find_or_create_by!(episode: episode) do |t|
            t.content = sample_transcript(pd[:title], ep_num)
          end

          # Create summary
          unless episode.summary
            Summary.create!(
              episode: episode,
              sections: sample_sections(pd[:title], ep_num),
              quotes: sample_quotes(ep_num)
            )
          end
          ready_episodes += 1
        else
          pending_episodes += 1
        end

        total_episodes += 1
      end
    end

    # --- Sample digest tracking events (for yesterday's digest) ---
    yesterday = (Date.current - 1).to_s
    existing_open = EmailEvent.find_by(user: user, event_type: "open", digest_date: yesterday)
    unless existing_open
      # Open event
      EmailEvent.create!(
        user: user,
        token: SecureRandom.urlsafe_base64(16),
        event_type: "open",
        digest_date: yesterday,
        triggered_at: 1.day.ago + 7.hours # Opened at 7 AM yesterday
      )

      # Click events for a few episodes
      sample_episodes = Episode.joins(podcast: :subscriptions)
        .where(subscriptions: { user_id: user.id })
        .limit(5)

      sample_episodes.each do |ep|
        EmailEvent.create!(
          user: user,
          token: SecureRandom.urlsafe_base64(16),
          event_type: "click",
          link_type: "summary",
          episode: ep,
          digest_date: yesterday,
          triggered_at: [ 1.day.ago + 7.hours + rand(1..30).minutes, nil ].sample
        )
        EmailEvent.create!(
          user: user,
          token: SecureRandom.urlsafe_base64(16),
          event_type: "click",
          link_type: "listen",
          episode: ep,
          digest_date: yesterday,
          triggered_at: [ 1.day.ago + 7.hours + rand(30..60).minutes, nil ].sample
        )
      end
    end

    event_count = EmailEvent.where(user: user).count

    # --- Second user: empty digest scenario ---
    empty_user = User.find_or_create_by!(email: "onboarding-empty@example.com") do |u|
      u.digest_enabled = true
    end
    empty_user.update!(digest_enabled: true, digest_sent_at: 1.minute.ago)

    # --- Third user: digest disabled ---
    disabled_user = User.find_or_create_by!(email: "onboarding-disabled@example.com") do |u|
      u.digest_enabled = false
    end
    disabled_user.update!(digest_enabled: false)

    # --- Summary ---
    puts
    puts "=== Onboarding QA Seed Summary ==="
    puts "Primary user:        #{user.email}"
    puts "Magic link:          /auth/verify?token=#{token}"
    puts "  (expires in 15 minutes — re-run task to refresh)"
    puts "Podcasts:            #{podcast_data.size} subscribed"
    puts "Episodes:            #{total_episodes} total (#{ready_episodes} with summaries, #{pending_episodes} pending)"
    puts "Tracking events:     #{event_count} (from yesterday's sample digest)"
    puts
    puts "Empty digest user:   #{empty_user.email} (digest_sent_at just now — no new episodes)"
    puts "Disabled user:       #{disabled_user.email} (digest_enabled: false)"
    puts
    puts "=== QA Scenarios ==="
    puts "1. Log in: /auth/verify?token=#{token}"
    puts "2. Check /episodes/:id — pick any episode with a summary"
    puts "3. Run SendDailyDigestJob.perform_now to send a digest"
    puts "4. Check letter_opener for the digest email"
    puts "5. Verify episodes grouped by show, summaries visible"
    puts "6. Verify 'Summary processing...' for pending episodes"
    puts "7. Click tracking links — verify redirect + event recorded"
    puts "8. Run `rake onboarding:engagement_report` to see stats"
    puts
    puts "=== Large Digest Test ==="
    puts "All #{total_episodes - (podcast_data.find { |p| p[:all_old] }[:episodes])} recent episodes "
    puts "will appear in the digest (exceeds 20+ threshold)"
  end
end

def sample_transcript(show_name, ep_num)
  "This is a sample transcript for #{show_name} Episode #{ep_num}. " \
    "The hosts discuss various topics related to technology and business. " \
    "This transcript is for QA testing purposes only and contains placeholder content. " \
    "In a real episode, this would be the full AssemblyAI transcription output."
end

def sample_sections(show_name, ep_num)
  [
    {
      "title" => "Introduction",
      "content" => "In this episode of #{show_name}, we dive into the latest developments " \
        "in the tech industry. Episode #{ep_num} covers some fascinating topics that " \
        "will change how you think about building software products."
    },
    {
      "title" => "Main Discussion",
      "content" => "The main topic today is about scaling systems and making decisions " \
        "under uncertainty. We explore how small teams can build products that serve " \
        "millions of users without overengineering their architecture."
    },
    {
      "title" => "Key Takeaways",
      "content" => "Start small, iterate fast, and listen to your users. The best products " \
        "come from tight feedback loops between builders and customers."
    }
  ]
end

def sample_quotes(ep_num)
  return [] if ep_num % 3 == 0 # Some episodes have no notable quotes

  [
    {
      "text" => "The best time to ship was yesterday. The second best time is right now.",
      "start_time" => 300 + (ep_num * 10)
    },
    {
      "text" => "You don't need a perfect architecture. You need a working product.",
      "start_time" => 900 + (ep_num * 15)
    }
  ]
end
