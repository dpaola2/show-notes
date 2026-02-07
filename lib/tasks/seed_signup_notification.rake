namespace :pipeline do
  desc "Create a test user and send a signup notification email (QA verification)"
  task seed_signup_notification: :environment do
    test_email = "pipeline-test-signup@example.com"

    # Clean up existing test user so the mailer fires every run
    user = User.find_by(email: test_email)
    if user
      user.destroy!
      puts "Destroyed existing test user: #{test_email}"
    end

    user = User.create!(email: test_email)
    puts "Created test user: #{user.email} (id: #{user.id})"

    SignupNotificationMailer.new_signup(user).deliver_later
    puts "Enqueued signup notification email"

    puts
    puts "=== Summary ==="
    puts "Test user email:    #{user.email}"
    puts "Signed up at:       #{user.created_at}"
    puts "Notification to:    #{SignupNotificationMailer::RECIPIENTS.join(', ')}"
    puts
    puts "=== Verify ==="
    puts "Development: Open Letter Opener at /letter_opener"
    puts "Staging/Prod: Check inboxes for #{SignupNotificationMailer::RECIPIENTS.join(', ')}"
  end
end
