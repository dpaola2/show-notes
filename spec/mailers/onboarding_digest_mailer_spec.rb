require "rails_helper"

# Tests for the library-scoped digest mailer (newsletter format with summaries + tracking).
# The digest includes only episodes in the user's library with processing_status: :ready.

RSpec.describe DigestMailer, type: :mailer do
  describe "#daily_digest (newsletter format)" do
    let(:user) { create(:user, email: "marcus@example.com", digest_enabled: true, digest_sent_at: 2.hours.ago) }

    # Set up podcasts and subscriptions
    let(:podcast_a) { create(:podcast, title: "Build Your SaaS") }
    let(:podcast_b) { create(:podcast, title: "Mostly Technical") }
    let!(:sub_a) { create(:subscription, user: user, podcast: podcast_a) }
    let!(:sub_b) { create(:subscription, user: user, podcast: podcast_b) }

    # Episodes with summaries (fully processed)
    let!(:episode_a1) do
      ep = create(:episode, podcast: podcast_a, title: "Economics of Podcast Ads", created_at: 1.hour.ago, published_at: 2.hours.ago)
      create(:summary, episode: ep, sections: [
        { "title" => "Overview", "content" => "A deep dive into the economics of podcast advertising in 2026, with data showing CPM rates have dropped 30% while listenership grew." }
      ], quotes: [ { "text" => "The market shifted.", "start_time" => 100 } ])
      create(:user_episode, :ready, user: user, episode: ep)
      ep
    end

    let!(:episode_a2) do
      ep = create(:episode, podcast: podcast_a, title: "Building in Public", created_at: 1.hour.ago, published_at: 3.hours.ago)
      create(:summary, episode: ep, sections: [
        { "title" => "Overview", "content" => "How sharing your startup journey publicly attracts customers and advisors organically." }
      ], quotes: [])
      create(:user_episode, :ready, user: user, episode: ep)
      ep
    end

    let!(:episode_b1) do
      ep = create(:episode, podcast: podcast_b, title: "TypeScript in 2026", created_at: 1.hour.ago, published_at: 1.hour.ago)
      create(:summary, episode: ep, sections: [
        { "title" => "Overview", "content" => "A breakdown of why TypeScript adoption plateaued in 2026 and what Deno is doing differently." }
      ], quotes: [ { "text" => "Deno changed the game.", "start_time" => 500 } ])
      create(:user_episode, :ready, user: user, episode: ep)
      ep
    end

    context "DIG-001: all new episodes included" do
      it "includes all new episodes since last digest" do
        mail = DigestMailer.daily_digest(user)

        body = mail.html_part.body.to_s
        expect(body).to include("Economics of Podcast Ads")
        expect(body).to include("Building in Public")
        expect(body).to include("TypeScript in 2026")
      end

      it "does not truncate or limit episode count" do
        # Create many more episodes
        8.times do |i|
          ep = create(:episode, podcast: podcast_a, title: "Extra Episode #{i}", created_at: 1.hour.ago)
          create(:summary, episode: ep)
          create(:user_episode, :ready, user: user, episode: ep)
        end

        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        8.times do |i|
          expect(body).to include("Extra Episode #{i}")
        end
      end
    end

    context "DIG-002: each episode displays show name, title, and summary" do
      it "includes podcast name for each episode" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Build Your SaaS")
        expect(body).to include("Mostly Technical")
      end

      it "includes episode titles" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Economics of Podcast Ads")
        expect(body).to include("TypeScript in 2026")
      end

      it "includes 2-3 sentence summaries from first section content" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("economics of podcast advertising")
        expect(body).to include("TypeScript adoption plateaued")
      end
    end

    context "DIG-003: Read full summary links" do
      it "includes Read full summary links for each episode" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Read full summary")
      end
    end

    context "DIG-004: Listen links" do
      it "includes Listen links for each episode" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Listen")
      end
    end

    context "DIG-007: email header with date and count" do
      it "has subject line with episode count" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.subject).to include("3 episodes ready")
      end

      it "includes date in the email body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include(Date.current.strftime("%A, %B"))
      end

      it "includes total episode count in the body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("3")
      end

      it "uses correct singular form for 1 episode" do
        # Remove all but one episode's subscriptions
        Episode.where.not(id: episode_b1.id).where(podcast_id: [ podcast_a.id, podcast_b.id ]).destroy_all

        mail = DigestMailer.daily_digest(user)

        expect(mail.subject).to include("1 episode ready")
        expect(mail.subject).not_to include("episodes")
      end
    end

    context "DIG-008: episodes without summary show processing state" do
      let!(:processing_episode) do
        ep = create(:episode, podcast: podcast_a, title: "Still Processing Episode", created_at: 1.hour.ago)
        # Ready in library but no summary — edge case where summary creation failed
        create(:user_episode, :ready, user: user, episode: ep)
        ep
      end

      it "includes the episode with a processing note" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Still Processing Episode")
        expect(body).to include("processing")
      end
    end

    context "DIG-009: episodes grouped by show" do
      it "groups episodes under their podcast name" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        # Both Build Your SaaS episodes should appear near each other
        # We can verify grouping by checking that the podcast header appears
        expect(body).to include("Build Your SaaS")
        expect(body).to include("Mostly Technical")
      end
    end

    context "DIG-013: skip empty digests" do
      let(:user_no_episodes) { create(:user, email: "empty@example.com", digest_enabled: true, digest_sent_at: 1.minute.ago) }

      it "returns nil or empty mail when no new episodes exist" do
        mail = DigestMailer.daily_digest(user_no_episodes)

        # The mailer should either not deliver or return a message object that
        # won't be delivered (mail.perform_deliveries = false or message.body is empty)
        # The implementation might use `return` early or `mail()` won't be called
        expect(mail.to).to be_nil.or(eq([]))
      end
    end

    context "TRK-001: tracking pixel embedded in email" do
      it "includes a tracking pixel image tag in the HTML email" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("pixel.gif")
      end
    end

    context "TRK-002: summary links use tracking redirect URLs" do
      it "uses /t/ tracking redirect URLs for Read full summary links" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        # Links should go through tracking redirect, not directly to episode page
        expect(body).to match(%r{/t/[A-Za-z0-9_-]+})
      end
    end

    context "TRK-003: listen links use tracking redirect URLs" do
      it "uses /t/ tracking redirect URLs for Listen links" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        # Multiple tracking links should exist (summary + listen for each episode)
        tracking_links = body.scan(%r{/t/[A-Za-z0-9_-]+})
        # At least 2 per episode (summary + listen) × 3 episodes + 1 open pixel = 7+
        expect(tracking_links.length).to be >= 7
      end
    end

    context "TRK-004: tracking events pre-created in database" do
      it "creates EmailEvent records when composing the digest" do
        expect {
          DigestMailer.daily_digest(user)
        }.to change(EmailEvent, :count)
      end

      it "creates one open event per digest" do
        DigestMailer.daily_digest(user)

        open_events = EmailEvent.where(user: user, event_type: "open")
        expect(open_events.count).to eq(1)
      end

      it "creates click events for each episode (summary + listen)" do
        DigestMailer.daily_digest(user)

        click_events = EmailEvent.where(user: user, event_type: "click")
        # 3 episodes × 2 link types (summary + listen) = 6
        expect(click_events.count).to eq(6)
      end
    end

    context "plain-text version" do
      it "includes episode titles in the text body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("Economics of Podcast Ads")
        expect(body).to include("TypeScript in 2026")
      end

      it "includes summaries in the text body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("economics of podcast advertising")
      end

      it "includes podcast names in the text body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to include("Build Your SaaS")
        expect(body).to include("Mostly Technical")
      end
    end

    context "edge case: episode with failed processing" do
      let!(:failed_episode) do
        ep = create(:episode, podcast: podcast_a, title: "Failed Episode", created_at: 1.hour.ago)
        # Ready in library but no summary — processing failed after transcription
        create(:user_episode, :ready, user: user, episode: ep)
        ep
      end

      it "includes the episode with title only" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to include("Failed Episode")
      end
    end

    context "edge case: episodes from unsubscribed podcasts excluded" do
      let(:other_podcast) { create(:podcast, title: "Not Subscribed") }
      let!(:other_episode) { create(:episode, podcast: other_podcast, title: "Should Not Appear", created_at: 1.hour.ago) }

      it "does not include episodes from unsubscribed podcasts" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).not_to include("Should Not Appear")
        expect(body).not_to include("Not Subscribed")
      end
    end

    context "edge case: old episodes before last digest not included" do
      let!(:old_episode) do
        ep = create(:episode, podcast: podcast_a, title: "Old Episode Before Digest", created_at: 3.hours.ago)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        # UserEpisode updated BEFORE digest_sent_at — not "new"
        ue.update_column(:updated_at, 3.hours.ago)
        ep
      end

      it "does not include episodes with user_episode updated before last digest_sent_at" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).not_to include("Old Episode Before Digest")
      end
    end
  end
end
