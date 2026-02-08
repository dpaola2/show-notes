namespace :onboarding do
  desc "Print engagement report: digest opens and clicks by date, type, and link type"
  task engagement_report: :environment do
    puts "=== Onboarding Engagement Report ==="
    puts "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M')}"
    puts

    # --- Opens per user per day ---
    puts "--- Opens by User & Date ---"
    opens = EmailEvent.opens.triggered
      .order(:digest_date, :user_id)
      .group(:user_id, :digest_date)
      .count

    if opens.empty?
      puts "  (no opens recorded)"
    else
      opens.each do |(user_id, date), count|
        user = User.find(user_id)
        puts "  #{date}  #{user.email}  #{count} open(s)"
      end
    end
    puts

    # --- Clicks per episode ---
    puts "--- Clicks by Episode ---"
    clicks = EmailEvent.clicks.triggered
      .where.not(episode_id: nil)
      .group(:episode_id, :link_type)
      .count

    if clicks.empty?
      puts "  (no clicks recorded)"
    else
      episode_ids = clicks.keys.map(&:first).uniq
      episodes = Episode.where(id: episode_ids).includes(:podcast).index_by(&:id)

      clicks.each do |(episode_id, link_type), count|
        episode = episodes[episode_id]
        show = episode&.podcast&.title || "Unknown"
        title = episode&.title || "Unknown"
        puts "  #{show} — #{title}  [#{link_type}] #{count} click(s)"
      end
    end
    puts

    # --- Summary stats ---
    total_opens = EmailEvent.opens.triggered.count
    total_clicks = EmailEvent.clicks.triggered.count
    total_events = EmailEvent.count
    triggered_events = EmailEvent.triggered.count
    unique_users = EmailEvent.triggered.select(:user_id).distinct.count

    puts "--- Summary ---"
    puts "  Total events created: #{total_events}"
    puts "  Total triggered:      #{triggered_events}"
    puts "  Opens:                #{total_opens}"
    puts "  Clicks:               #{total_clicks}"
    puts "  Unique users:         #{unique_users}"
  end
end
