require "rails_helper"

RSpec.describe DigestMailer, type: :mailer do
  describe "#daily_digest — featured episode layout" do
    let(:user) { create(:user, email: "digest@example.com", digest_enabled: true, digest_sent_at: 2.hours.ago) }
    let(:podcast) { create(:podcast, title: "Tech Talk") }
    let!(:subscription) { create(:subscription, user: user, podcast: podcast) }

    # ── M1: Subject Line Format ──────────────────────────────────────────

    context "SL-001: subject uses featured episode podcast and title" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "The Future of AI")
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "formats subject as Podcast Name: Episode Title" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.subject).to eq("Tech Talk: The Future of AI")
      end
    end

    context "SL-002: subject appends (+N more) when additional episodes exist" do
      let!(:episodes) do
        3.times.map do |i|
          ep = create(:episode, podcast: podcast, title: "Episode #{i}")
          create(:summary, episode: ep)
          ue = create(:user_episode, :ready, user: user, episode: ep)
          ue.update_column(:updated_at, (i + 1).hours.ago)
          ep
        end
      end

      it "appends (+2 more) to subject when 2 recent episodes exist" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.subject).to include("(+2 more)")
      end
    end

    context "RE-004: single episode subject" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Solo Episode")
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "formats subject as Podcast: Title without (+N more) for single episode" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.subject).to include("Tech Talk: Solo Episode")
      end
    end

    # ── M1: EmailEvent Creation ──────────────────────────────────────────

    context "FE-004: click events for featured vs recent episodes" do
      let!(:episodes) do
        3.times.map do |i|
          ep = create(:episode, podcast: podcast, title: "Event Episode #{i}")
          create(:summary, episode: ep)
          ue = create(:user_episode, :ready, user: user, episode: ep)
          ue.update_column(:updated_at, (i + 1).hours.ago)
          ep
        end
      end

      it "does not create a listen click event for the featured episode" do
        DigestMailer.daily_digest(user)

        # Featured episode is the most recently updated (Episode 0, updated 1 hour ago)
        featured = episodes.first
        listen_event = EmailEvent.find_by(
          user: user, episode: featured, event_type: "click", link_type: "listen"
        )
        expect(listen_event).to be_nil
      end
    end

    # ── M1: NullMail Edge Cases ──────────────────────────────────────────

    context "FE-006: NullMail when all episodes lack summaries" do
      it "returns NullMail when all qualifying episodes have no summaries" do
        3.times do
          ep = create(:episode, podcast: podcast)
          ue = create(:user_episode, :ready, user: user, episode: ep)
          ue.update_column(:updated_at, 1.hour.ago)
        end

        mail = DigestMailer.daily_digest(user)
        expect(mail.to).to be_nil
      end
    end

    # ── M1: Deliver-Later Fallback ───────────────────────────────────────

    context "deliver_later fallback with new layout" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Fallback Featured")
        create(:summary, episode: ep, sections: [
          { "title" => "Takeaway", "content" => "The key insight from this episode." }
        ])
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "uses the new subject line format in deliver_later fallback" do
        mail = DigestMailer.daily_digest(user)
        Thread.current[:digest_mailer_data] = nil
        user.update!(digest_sent_at: Time.current)

        expect(mail.subject).to include("Tech Talk: Fallback Featured")
      end

      it "renders full summary section headings in deliver_later fallback" do
        mail = DigestMailer.daily_digest(user)
        Thread.current[:digest_mailer_data] = nil
        user.update!(digest_sent_at: Time.current)

        body = mail.html_part.body.to_s
        expect(body).to include("Takeaway")
      end
    end

    # ── M2: Featured Episode HTML Template ───────────────────────────────

    context "featured episode rendering in HTML" do
      let!(:featured_episode) do
        ep = create(:episode, podcast: podcast, title: "Featured Deep Dive")
        create(:summary, episode: ep, sections: [
          { "title" => "Key Takeaways", "content" => "First section with important insights about the topic." },
          { "title" => "Expert Analysis", "content" => "Second section diving deeper into the implications." },
          { "title" => "Future Outlook", "content" => "Third section about what comes next." }
        ], quotes: [
          { "text" => "This changes everything we know about the industry.", "start_time" => 500 },
          { "text" => "Innovation happens at the intersection of disciplines.", "start_time" => 1200 }
        ])
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 30.minutes.ago)
        ep
      end

      let!(:recent_episodes) do
        2.times.map do |i|
          ep = create(:episode, podcast: podcast, title: "Recent Episode #{i}")
          create(:summary, episode: ep)
          ue = create(:user_episode, :ready, user: user, episode: ep)
          ue.update_column(:updated_at, (i + 2).hours.ago)
          ep
        end
      end

      it "FE-002: displays all summary section headings for the featured episode" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Key Takeaways")
        expect(body).to include("Expert Analysis")
        expect(body).to include("Future Outlook")
      end

      it "FE-002: displays full content of all summary sections" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Second section diving deeper into the implications")
        expect(body).to include("Third section about what comes next")
      end

      it "FE-003: displays quotes for the featured episode" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("This changes everything we know about the industry")
        expect(body).to include("Innovation happens at the intersection of disciplines")
      end

      it "FE-004: shows Read in app link for featured episode" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Read in app")
      end

      it "RE-001: shows Latest episodes heading when multiple episodes exist" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Latest episodes")
      end

      it "RE-006: displays That's all for now sign-off" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("That\u2019s all for now").or include("That's all for now")
      end
    end

    # ── M2: Single Episode Layout ────────────────────────────────────────

    context "single episode rendering" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Only Episode")
        create(:summary, episode: ep, sections: [
          { "title" => "Main Points", "content" => "First section content for the only episode." },
          { "title" => "Key Insights", "content" => "Second section that proves full rendering works." }
        ], quotes: [
          { "text" => "A memorable quote from the only episode.", "start_time" => 300 }
        ])
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "RE-004: renders full summary with all sections for a single episode" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Key Insights")
        expect(body).to include("Second section that proves full rendering works")
      end
    end

    # ── M2: Text Template ────────────────────────────────────────────────

    context "text template" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Text Template Episode")
        create(:summary, episode: ep, sections: [
          { "title" => "Overview", "content" => "The overview of this episode covers many topics." },
          { "title" => "Deep Dive", "content" => "A detailed exploration of the main subject." }
        ], quotes: [
          { "text" => "This quote should appear in the text version.", "start_time" => 600 }
        ])
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "TXT-001: includes full summary section headings in text template" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("Deep Dive")
      end

      it "TXT-001: includes full summary content in text template" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("detailed exploration of the main subject")
      end

      it "TXT-001: includes quotes in text template" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("This quote should appear in the text version")
      end

      it "TXT-001: includes That's all for now in text template" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("That's all for now")
      end

      it "TXT-001: includes Read in app in text template" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("Read in app")
      end
    end

    # ── M2/M4: Overflow and Header Count ─────────────────────────────────

    context "more than 6 qualifying episodes" do
      let!(:episodes) do
        8.times.map do |i|
          ep = create(:episode, podcast: podcast, title: "Overflow Episode #{i}")
          create(:summary, episode: ep)
          ue = create(:user_episode, :ready, user: user, episode: ep)
          ue.update_column(:updated_at, (i + 1).hours.ago)
          ep
        end
      end

      it "omits episodes beyond the 6th (1 featured + 5 recent)" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        # Episodes 6 and 7 are the oldest — should be omitted
        expect(body).not_to include("Overflow Episode 6")
        expect(body).not_to include("Overflow Episode 7")
      end

      it "shows displayed episode count in header, not total qualifying" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("6 episodes")
      end
    end

    # ── M4: Edge Cases ───────────────────────────────────────────────────

    context "quotes containing markdown characters" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Markdown Quote Episode")
        create(:summary, episode: ep, sections: [
          { "title" => "Discussion", "content" => "A discussion about formatting." }
        ], quotes: [
          { "text" => "This is **bold** and _italic_ in markdown", "start_time" => 100 }
        ])
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "renders quotes as plain text without markdown processing" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("**bold**")
      end
    end
  end
end
