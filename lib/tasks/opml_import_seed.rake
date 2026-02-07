namespace :pipeline do
  desc "Seed test data for OPML import QA (idempotent, dev/staging only)"
  task seed_opml_import: :environment do
    unless Rails.env.development? || Rails.env.staging?
      abort "This task is only for development and staging environments"
    end

    test_email = "pipeline-test-opml@example.com"

    # --- Test user ---
    user = User.find_or_create_by!(email: test_email)
    token = user.generate_magic_token!
    puts "Test user: #{user.email} (id: #{user.id})"

    # --- Pre-existing subscriptions (for dedup testing) ---
    # These feed URLs appear in valid_podcasts.opml and large_import.opml,
    # so uploading those files will trigger the "already subscribed" skip path.
    preexisting_feeds = [
      { feed_url: "https://feeds.simplecast.com/the-daily", title: "The Daily" },
      { feed_url: "https://feeds.example.com/acquired", title: "Acquired" }
    ]

    preexisting_feeds.each do |attrs|
      podcast = Podcast.find_or_create_by!(feed_url: attrs[:feed_url]) do |p|
        p.guid = attrs[:feed_url]
        p.title = attrs[:title]
      end
      user.subscriptions.find_or_create_by!(podcast: podcast)
    end

    sub_count = user.subscriptions.count
    puts "Pre-existing subscriptions: #{sub_count}"

    # --- Fixture file paths ---
    fixtures_dir = Rails.root.join("spec", "fixtures", "files")
    opml_files = %w[
      valid_podcasts.opml
      nested_folders.opml
      large_import.opml
      empty_feeds.opml
      duplicate_feeds.opml
    ]

    # --- Summary ---
    puts
    puts "=== OPML Import QA Summary ==="
    puts "User email:          #{user.email}"
    puts "Magic link:          /auth/verify?token=#{token}"
    puts "  (expires in 15 minutes — re-run task to refresh)"
    puts "Subscriptions:       #{sub_count} pre-existing (The Daily, Acquired)"
    puts
    puts "Sample OPML files:"
    opml_files.each do |file|
      path = fixtures_dir.join(file)
      status = File.exist?(path) ? "OK" : "MISSING"
      puts "  #{status}  #{path}"
    end
    puts
    puts "=== QA Steps ==="
    puts "1. Open /auth/verify?token=#{token} to log in"
    puts "2. Go to /import/new and upload an OPML file"
    puts "3. valid_podcasts.opml — 3 feeds (2 already subscribed, 1 new)"
    puts "4. large_import.opml — 12 feeds in folders (2 already subscribed, 10 new)"
    puts "5. empty_feeds.opml — no podcast feeds (should show error)"
    puts "6. duplicate_feeds.opml — duplicate feed URLs (should dedup)"
    puts "7. nested_folders.opml — 5 feeds in nested folders (should flatten)"
  end
end
