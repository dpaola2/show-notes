namespace :shareable do
  desc "Seed test data for shareable episode cards QA (idempotent, dev/test only)"
  task seed: :environment do
    unless Rails.env.development? || Rails.env.test?
      abort "This task is only for development/test environments"
    end

    test_email = "share-qa@example.com"

    # --- Test user with subscription ---
    user = User.find_or_create_by!(email: test_email) do |u|
      u.digest_enabled = true
    end
    token = user.generate_magic_token!

    # --- Podcast with artwork ---
    podcast = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/share-qa-show") do |p|
      p.guid = "share-qa-show"
      p.title = "Share QA Podcast"
      p.artwork_url = "https://picsum.photos/600/600"
    end
    podcast.update!(artwork_url: "https://picsum.photos/600/600")
    user.subscriptions.find_or_create_by!(podcast: podcast)

    episodes_created = []

    # --- Episode 1: Happy path (summary + OG image) ---
    ep1 = find_or_create_episode(podcast, "share-qa-ep-1",
      title: "The Future of AI Podcasting",
      published_at: 2.days.ago)
    create_summary_for(ep1,
      sections: [
        { "title" => "Key Insights", "content" => "AI is transforming how we consume podcasts. Automated summaries let listeners triage episodes in seconds." },
        { "title" => "Deep Dive", "content" => "The hosts explore how large language models can extract key points, notable quotes, and actionable takeaways from long-form audio." }
      ],
      quotes: [
        { "text" => "The best podcast is the one you actually have time to listen to.", "start_time" => 245 },
        { "text" => "Summaries aren't a replacement — they're a filter.", "start_time" => 892 }
      ])
    attach_placeholder_og_image(ep1)
    episodes_created << { id: ep1.id, scenario: "Happy path (summary + OG image)" }

    # --- Episode 2: Summary but no OG image (fallback OG tags) ---
    ep2 = find_or_create_episode(podcast, "share-qa-ep-2",
      title: "Building in Public: Lessons Learned",
      published_at: 3.days.ago)
    create_summary_for(ep2,
      sections: [
        { "title" => "Transparency", "content" => "Building in public creates accountability and attracts early adopters who feel invested in the journey." },
        { "title" => "Pitfalls", "content" => "Not everything should be shared. Competitive insights and user data require discretion." }
      ],
      quotes: [
        { "text" => "Ship it, share it, learn from it.", "start_time" => 180 }
      ])
    episodes_created << { id: ep2.id, scenario: "Summary, no OG image (fallback OG tags)" }

    # --- Episode 3: No summary (public page shows 'not yet available') ---
    ep3 = find_or_create_episode(podcast, "share-qa-ep-3",
      title: "Coming Soon: The Untold Story",
      published_at: 1.day.ago)
    episodes_created << { id: ep3.id, scenario: "No summary (processing message)" }

    # --- Episode 4: Very long title (100+ chars) for truncation testing ---
    ep4 = find_or_create_episode(podcast, "share-qa-ep-4",
      title: "This Episode Has an Extraordinarily Long Title That Exceeds One Hundred Characters to Test How the OG Image and Meta Tags Handle Truncation Gracefully",
      published_at: 4.days.ago)
    create_summary_for(ep4,
      sections: [
        { "title" => "Overview", "content" => "Testing how the system handles very long episode titles in OG images, meta tags, and the public page layout." }
      ],
      quotes: [
        { "text" => "If your title needs a scroll bar, it's too long.", "start_time" => 60 }
      ])
    attach_placeholder_og_image(ep4)
    episodes_created << { id: ep4.id, scenario: "Long title (100+ chars) for truncation" }

    # --- Episode 5: Summary with no quotes (fallback to section content for OG image) ---
    ep5 = find_or_create_episode(podcast, "share-qa-ep-5",
      title: "Data-Driven Decision Making",
      published_at: 5.days.ago)
    create_summary_for(ep5,
      sections: [
        { "title" => "Metrics That Matter", "content" => "Focus on leading indicators rather than vanity metrics. Revenue per user beats total signups every time." },
        { "title" => "Building Dashboards", "content" => "The best dashboard is the one your team actually looks at. Start with three metrics and expand only when needed." }
      ],
      quotes: [])
    attach_placeholder_og_image(ep5)
    episodes_created << { id: ep5.id, scenario: "No quotes (OG image uses section content)" }

    # --- Share events across different targets ---
    %w[clipboard twitter linkedin native].each do |target|
      ShareEvent.find_or_create_by!(episode: ep1, share_target: target, user: user) do |se|
        se.user_agent = "Mozilla/5.0 QA Seed"
        se.referrer = "http://localhost:3000/e/#{ep1.id}"
      end
    end

    # Unauthenticated share events
    ShareEvent.find_or_create_by!(episode: ep2, share_target: "clipboard", user: nil) do |se|
      se.user_agent = "Mozilla/5.0 Anonymous"
    end

    share_count = ShareEvent.count

    # --- User with referral_source (UTM attribution scenario) ---
    referred_user = User.find_or_create_by!(email: "share-referred@example.com")
    referred_user.update!(referral_source: "share") unless referred_user.referral_source.present?

    # --- Summary ---
    puts
    puts "=== Shareable Episode Cards QA Seed Summary ==="
    puts "Test user:           #{user.email} (id: #{user.id})"
    puts "Magic link:          /auth/verify?token=#{token}"
    puts "Podcast:             #{podcast.title} (artwork: #{podcast.artwork_url})"
    puts
    puts "Episodes:"
    episodes_created.each do |ep|
      puts "  /e/#{ep[:id]} — #{ep[:scenario]}"
    end
    puts
    puts "Share events:        #{share_count} total"
    puts "Referred user:       #{referred_user.email} (referral_source: #{referred_user.referral_source})"
    puts
    puts "=== Manual QA Checklist ==="
    puts "1. Visit /e/#{ep1.id} — verify summary, artwork, OG image, share button"
    puts "2. Visit /e/#{ep2.id} — verify fallback OG tags (no og:image)"
    puts "3. Visit /e/#{ep3.id} — verify 'not yet available' message"
    puts "4. Visit /e/#{ep4.id} — verify long title truncation"
    puts "5. Visit /e/#{ep5.id} — verify OG image uses section content (no quotes)"
    puts "6. Click Share → Copy Link — verify clipboard + toast"
    puts "7. Click Share → Twitter/X — verify pre-filled tweet opens"
    puts "8. Click Share → LinkedIn — verify LinkedIn share opens"
    puts "9. Check UTM params in copied/shared links"
    puts "10. Log in as #{user.email} — verify share button on /episodes and /library views"
    puts
  end
end

def find_or_create_episode(podcast, guid, title:, published_at:)
  episode = podcast.episodes.find_or_initialize_by(guid: guid)
  episode.assign_attributes(
    title: title,
    audio_url: "https://audio.example.com/#{guid}.mp3",
    published_at: published_at,
    duration_seconds: rand(1200..3600),
    description: "QA test episode: #{title}"
  )
  episode.save!
  episode
end

def create_summary_for(episode, sections:, quotes:)
  return if episode.summary.present?

  Summary.create!(episode: episode, sections: sections, quotes: quotes)
end

def attach_placeholder_og_image(episode)
  return if episode.og_image.attached?

  # Generate a minimal placeholder OG image via vips
  begin
    image_data = OgImageGenerator.generate(episode)
    episode.og_image.attach(
      io: StringIO.new(image_data),
      filename: "og_#{episode.id}.png",
      content_type: "image/png"
    )
  rescue => e
    puts "  Warning: Could not generate OG image for episode #{episode.id}: #{e.message}"
  end
end
