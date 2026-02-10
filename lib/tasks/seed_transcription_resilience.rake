namespace :seed do
  desc "Seed test data for transcription resilience QA: episodes in all processing states, retry history, stuck jobs (idempotent, dev only)"
  task transcription_resilience: :environment do
    unless Rails.env.development?
      abort "This task is only for development environments"
    end

    test_email = "transcription-qa@example.com"

    # --- Test user ---
    user = User.find_or_create_by!(email: test_email)
    token = user.generate_magic_token!

    puts "Test user: #{user.email} (id: #{user.id})"

    # --- Test podcast ---
    podcast = Podcast.find_or_create_by!(feed_url: "https://feeds.example.com/resilience-qa") do |p|
      p.guid = "resilience-qa-podcast"
      p.title = "Resilience QA Show"
    end
    user.subscriptions.find_or_create_by!(podcast: podcast)

    # --- Episode definitions with desired states ---
    episode_configs = [
      # Inbox episodes
      { slug: "inbox-pending",       title: "Inbox — Pending Episode",           location: :inbox,   status: :pending },
      { slug: "inbox-downloading",   title: "Inbox — Downloading Audio",         location: :inbox,   status: :downloading },
      { slug: "inbox-transcribing",  title: "Inbox — Transcribing",              location: :inbox,   status: :transcribing },
      { slug: "inbox-summarizing",   title: "Inbox — Generating Summary",        location: :inbox,   status: :summarizing },
      { slug: "inbox-ready",         title: "Inbox — Ready (with summary)",      location: :inbox,   status: :ready,  with_content: true },
      { slug: "inbox-error-rate",    title: "Inbox — Rate Limit Error",          location: :inbox,   status: :error,  error: "AssemblyAI rate limit exceeded: 429 Too Many Requests", retry_count: 2 },
      { slug: "inbox-error-generic", title: "Inbox — Generic API Error",         location: :inbox,   status: :error,  error: "AssemblyAI API error: Connection refused" },
      { slug: "inbox-error-timeout", title: "Inbox — Processing Timed Out",      location: :inbox,   status: :error,  error: "Processing timed out after 30 minutes and 1 second" },

      # Library episodes
      { slug: "lib-pending",         title: "Library — Pending Episode",         location: :library, status: :pending },
      { slug: "lib-transcribing",    title: "Library — Transcribing",            location: :library, status: :transcribing },
      { slug: "lib-summarizing",     title: "Library — Generating Summary",      location: :library, status: :summarizing },
      { slug: "lib-ready",           title: "Library — Ready Episode",           location: :library, status: :ready,  with_content: true },
      { slug: "lib-ready-2",         title: "Library — Another Ready Episode",   location: :library, status: :ready,  with_content: true },
      { slug: "lib-error-rate",      title: "Library — Rate Limit Error",        location: :library, status: :error,  error: "AssemblyAI rate limit exceeded: 429 Too Many Requests", retry_count: 3 },
      { slug: "lib-error-generic",   title: "Library — Unexpected Error",        location: :library, status: :error,  error: "undefined method 'content' for nil:NilClass" },
      { slug: "lib-error-retried",   title: "Library — Failed After 5 Retries",  location: :library, status: :error,  error: "AssemblyAI rate limit exceeded — retry 5/5 at 2026-02-10 12:30:00", retry_count: 5 },

      # Stuck episodes (transcribing with old updated_at — for DetectStuckProcessingJob testing)
      { slug: "stuck-transcribing",  title: "Stuck — Transcribing for 1 Hour",   location: :library, status: :transcribing, stuck: true },
      { slug: "stuck-summarizing",   title: "Stuck — Summarizing for 2 Hours",   location: :inbox,   status: :summarizing,  stuck: true, stuck_hours: 2 },
    ]

    counts = Hash.new(0)

    episode_configs.each do |config|
      guid = "resilience-qa-#{config[:slug]}"

      episode = Episode.find_or_initialize_by(guid: guid)
      episode.assign_attributes(
        podcast: podcast,
        title: config[:title],
        audio_url: "https://audio.example.com/resilience-qa/#{config[:slug]}.mp3",
        published_at: rand(1..48).hours.ago,
        duration_seconds: rand(1200..5400),
        description: "QA test episode: #{config[:title]}"
      )

      # Set episode-level processing state
      episode.processing_status = config[:status]
      if config[:error]
        episode.processing_error = config[:error]
        episode.last_error_at = rand(5..60).minutes.ago
      else
        episode.processing_error = nil
        episode.last_error_at = nil
      end
      episode.save!

      # Create transcript + summary for ready episodes
      if config[:with_content]
        Transcript.find_or_create_by!(episode: episode) do |t|
          t.content = "Sample transcript for #{config[:title]}. This is placeholder content for QA testing."
        end

        unless episode.summary
          Summary.create!(
            episode: episode,
            sections: [
              { "title" => "Overview", "content" => "This is a sample summary for #{config[:title]}." },
              { "title" => "Key Points", "content" => "The episode covers important topics for QA verification." }
            ],
            quotes: [
              { "text" => "This is a notable quote from the episode.", "start_time" => 120 }
            ]
          )
        end
      end

      # Create user_episode
      ue = UserEpisode.find_or_initialize_by(user: user, episode: episode)
      ue.assign_attributes(
        location: config[:location],
        processing_status: config[:status]
      )

      if config[:error]
        ue.processing_error = config[:error]
        ue.last_error_at = rand(5..60).minutes.ago
        ue.retry_count = config[:retry_count] || 0
        ue.next_retry_at = config[:retry_count].to_i >= 5 ? nil : rand(1..10).minutes.from_now
      else
        ue.processing_error = nil
        ue.last_error_at = nil
        ue.retry_count = 0
        ue.next_retry_at = nil
      end
      ue.save!

      # Backdate updated_at for stuck episodes (must use update_column to bypass AR callbacks)
      if config[:stuck]
        hours = config[:stuck_hours] || 1
        stuck_time = hours.hours.ago
        ue.update_column(:updated_at, stuck_time)
        episode.update_column(:updated_at, stuck_time)
      end

      counts[config[:status]] += 1
      counts["#{config[:location]}_total".to_sym] += 1
    end

    # --- Summary ---
    puts
    puts "=== Transcription Resilience QA Seed Summary ==="
    puts "User:               #{user.email}"
    puts "Magic link:         /auth/verify?token=#{token}"
    puts "  (expires in 15 minutes — re-run task to refresh)"
    puts "Podcast:            #{podcast.title}"
    puts
    puts "Episodes by status:"
    puts "  Pending:          #{counts[:pending]}"
    puts "  Downloading:      #{counts[:downloading]}"
    puts "  Transcribing:     #{counts[:transcribing]}"
    puts "  Summarizing:      #{counts[:summarizing]}"
    puts "  Ready:            #{counts[:ready]}"
    puts "  Error:            #{counts[:error]}"
    puts
    puts "Episodes by location:"
    puts "  Inbox:            #{counts[:inbox_total]}"
    puts "  Library:          #{counts[:library_total]}"
    puts
    puts "=== QA Scenarios ==="
    puts "1. Log in: /auth/verify?token=#{token}"
    puts "2. Inbox: verify status indicators (pending/transcribing/summarizing/ready/error)"
    puts "3. Inbox: click Retry on errored episodes — verify reset + notice"
    puts "4. Inbox: Add to Library on errored episode — verify it moves and re-enqueues"
    puts "5. Library: verify error messages + retry counts displayed"
    puts "6. Library: click Retry — verify reset + redirect back"
    puts "7. Library show: verify Retry button on errored episode"
    puts "8. Library show: verify Regenerate on ready episode still works"
    puts "9. Stuck jobs: run DetectStuckProcessingJob.perform_now"
    puts "   Then refresh — stuck episodes should now show 'Processing timed out' error"
    puts "10. Re-run this task to reset all state (idempotent)"
    puts
  end
end
