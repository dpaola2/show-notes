require "rails_helper"

RSpec.describe DigestMailer, type: :mailer do
  describe "#daily_digest" do
    let(:user) { create(:user, email: "test@example.com") }

    context "with inbox episodes" do
      let(:podcast) { create(:podcast, title: "Test Podcast") }
      let!(:inbox_episodes) do
        3.times.map do |i|
          episode = create(:episode, podcast: podcast, title: "Inbox Episode #{i}", duration_seconds: 3600)
          create(:user_episode, user: user, episode: episode, location: :inbox)
        end
      end

      it "sends email to user" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.to).to eq([ "test@example.com" ])
      end

      it "has correct subject with date" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.subject).to eq("Your Daily Podcast Digest - #{Date.current.strftime('%b %d')}")
      end

      it "includes inbox count in HTML body" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("3 new episodes")
      end

      it "includes episode titles in HTML body" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("Inbox Episode 0")
        expect(mail.html_part.body).to include("Test Podcast")
      end

      it "includes inbox link" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("Open Inbox")
      end

      it "includes episode titles in text body" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.text_part.body).to include("Inbox Episode 0")
        expect(mail.text_part.body).to include("Test Podcast")
      end
    end

    context "with more than 5 inbox episodes" do
      let(:podcast) { create(:podcast) }

      before do
        7.times do |i|
          episode = create(:episode, podcast: podcast, title: "Episode #{i}")
          create(:user_episode, user: user, episode: episode, location: :inbox)
        end
      end

      it "shows +N more message" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("+ 2 more episodes")
      end
    end

    context "with ready library episodes" do
      let(:podcast) { create(:podcast, title: "Library Podcast") }

      let!(:library_episode) do
        episode = create(:episode, podcast: podcast, title: "Ready Episode", duration_seconds: 7200)
        summary = create(:summary, episode: episode, sections: [
          { "title" => "Introduction", "content" => "This is the intro section with important content." },
          { "title" => "Main Topic", "content" => "The main discussion points are covered here." }
        ], quotes: [
          { "text" => "This is a notable quote from the episode.", "start_time" => 300 }
        ])
        create(:user_episode, user: user, episode: episode, location: :library, processing_status: :ready, updated_at: 1.hour.ago)
      end

      it "includes library section header" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("Recently Ready")
      end

      it "includes episode title" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("Ready Episode")
        expect(mail.html_part.body).to include("Library Podcast")
      end

      it "includes summary sections" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("Introduction")
        expect(mail.html_part.body).to include("This is the intro section")
      end

      it "includes quotes" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("This is a notable quote")
      end

      it "includes link to full summary" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("Read Full Summary")
      end
    end

    context "with no episodes" do
      it "shows empty state message" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).to include("No new episodes today")
      end
    end

    context "with old library episodes" do
      let(:podcast) { create(:podcast) }

      before do
        episode = create(:episode, podcast: podcast, title: "Old Episode")
        create(:summary, episode: episode)
        create(:user_episode, user: user, episode: episode, location: :library, processing_status: :ready, updated_at: 3.days.ago)
      end

      it "does not include episodes older than 2 days" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body).not_to include("Old Episode")
        expect(mail.html_part.body).not_to include("Recently Ready")
      end
    end

    it "includes unsubscribe information" do
      mail = DigestMailer.daily_digest(user)

      expect(mail.html_part.body).to include("daily digest enabled")
      expect(mail.html_part.body).to include("Manage your settings")
    end
  end
end
