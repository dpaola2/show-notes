require "rails_helper"

# These tests cover the library-scoped newsletter-format digest mailer.
# The comprehensive test suite is in onboarding_digest_mailer_spec.rb;
# this file provides basic sanity checks for the core mailer behavior.

RSpec.describe DigestMailer, type: :mailer do
  describe "#daily_digest" do
    let(:user) { create(:user, email: "test@example.com", digest_enabled: true, digest_sent_at: 2.hours.ago) }

    context "with subscribed podcast episodes" do
      let(:podcast) { create(:podcast, title: "Test Podcast") }
      let!(:subscription) { create(:subscription, user: user, podcast: podcast) }
      let!(:episodes) do
        3.times.map do |i|
          ep = create(:episode, podcast: podcast, title: "Episode #{i}", created_at: 1.hour.ago)
          create(:summary, episode: ep)
          create(:user_episode, :ready, user: user, episode: ep)
          ep
        end
      end

      it "sends email to user" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.to).to eq([ "test@example.com" ])
      end

      it "has correct subject with episode count" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.subject).to include("3 episodes ready")
      end

      it "includes episode count in HTML body" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body.to_s).to include("3")
      end

      it "includes episode titles in HTML body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Episode 0")
        expect(body).to include("Test Podcast")
      end

      it "includes episode titles in text body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("Episode 0")
        expect(body).to include("Test Podcast")
      end
    end

    context "with episode summaries" do
      let(:podcast) { create(:podcast, title: "Summary Podcast") }
      let!(:subscription) { create(:subscription, user: user, podcast: podcast) }

      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Ready Episode", created_at: 1.hour.ago)
        create(:summary, episode: ep, sections: [
          { "title" => "Introduction", "content" => "This is the intro section with important content." },
          { "title" => "Main Topic", "content" => "The main discussion points are covered here." }
        ], quotes: [
          { "text" => "This is a notable quote from the episode.", "start_time" => 300 }
        ])
        create(:user_episode, :ready, user: user, episode: ep)
        ep
      end

      it "includes summary content" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("intro section")
      end

      it "includes Read full summary link" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Read full summary")
      end
    end

    context "with no new episodes" do
      it "returns a null mail" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.to).to be_nil
      end
    end

    context "deliver_later fallback (no thread-local data)" do
      let(:podcast) { create(:podcast, title: "Fallback Podcast") }
      let!(:subscription) { create(:subscription, user: user, podcast: podcast) }
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Fallback Episode", created_at: 1.hour.ago)
        create(:summary, episode: ep)
        create(:user_episode, :ready, user: user, episode: ep)
        ep
      end

      it "renders episodes when digest_sent_at was bumped after scheduling" do
        # Simulate the deliver_later race condition:
        # 1. Class method runs, creates EmailEvents, stashes thread-local
        mail = DigestMailer.daily_digest(user)

        # 2. Thread-local is gone (different thread in deliver_later)
        Thread.current[:digest_mailer_data] = nil

        # 3. Job bumped digest_sent_at after scheduling
        user.update!(digest_sent_at: Time.current)

        # 4. Instance method renders — should still find episodes
        body = mail.html_part.body.to_s
        expect(body).to include("Fallback Episode")
      end

      it "does not create duplicate EmailEvents on re-invocation" do
        # First call (scheduling thread)
        DigestMailer.daily_digest(user)
        first_count = EmailEvent.count

        # Second call (simulates deliver_later worker re-invoking class method)
        DigestMailer.daily_digest(user)
        expect(EmailEvent.count).to eq(first_count)
      end
    end

    it "includes unsubscribe information" do
      podcast = create(:podcast)
      create(:subscription, user: user, podcast: podcast)
      ep = create(:episode, podcast: podcast, created_at: 1.hour.ago)
      create(:user_episode, :ready, user: user, episode: ep)

      mail = DigestMailer.daily_digest(user)

      expect(mail.html_part.body.to_s).to include("digest enabled")
      expect(mail.html_part.body.to_s).to include("Manage your settings")
    end
  end
end
