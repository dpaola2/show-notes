require "rails_helper"

RSpec.describe DigestMailer, type: :mailer do
  describe "#daily_digest — library-scoped behavior" do
    let(:user) { create(:user, email: "digest@example.com", digest_enabled: true, digest_sent_at: 2.hours.ago) }
    let(:podcast) { create(:podcast, title: "My Podcast") }
    let!(:subscription) { create(:subscription, user: user, podcast: podcast) }

    context "DIG-001: only includes library episodes" do
      let!(:library_episode) do
        ep = create(:episode, podcast: podcast, title: "Library Ready", created_at: 3.hours.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      let!(:inbox_episode) do
        ep = create(:episode, podcast: podcast, title: "Inbox Only", created_at: 1.hour.ago)
        create(:summary, episode: ep)
        create(:user_episode, user: user, episode: ep, location: :inbox)
        ep
      end

      it "includes library-ready episodes in the digest" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.html_part.body.to_s).to include("Library Ready")
      end

      it "excludes inbox episodes from the digest" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.html_part.body.to_s).not_to include("Inbox Only")
      end

      it "excludes archived episodes from the digest" do
        ep = create(:episode, podcast: podcast, title: "Archived Ep", created_at: 1.hour.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, user: user, episode: ep, location: :archive, processing_status: :ready)
        ue.update_column(:updated_at, 1.hour.ago)

        mail = DigestMailer.daily_digest(user)
        expect(mail.html_part.body.to_s).not_to include("Archived Ep")
      end
    end

    context "DIG-002: 24-hour cap on eligibility window" do
      it "includes library episodes within 24-hour cap when digest_sent_at is nil" do
        user.update!(digest_sent_at: nil)
        ep = create(:episode, podcast: podcast, title: "Recent Library", created_at: 25.hours.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 12.hours.ago)

        mail = DigestMailer.daily_digest(user)
        expect(mail.html_part.body.to_s).to include("Recent Library")
      end

      it "applies 24-hour cap when digest_sent_at is older than 24 hours" do
        user.update!(digest_sent_at: 3.days.ago)
        ep = create(:episode, podcast: podcast, title: "Capped Episode", created_at: 4.days.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 12.hours.ago)

        mail = DigestMailer.daily_digest(user)
        expect(mail.html_part.body.to_s).to include("Capped Episode")
      end

      it "excludes library episodes updated more than 24 hours ago" do
        user.update!(digest_sent_at: nil)
        ep = create(:episode, podcast: podcast, title: "Old Ready", created_at: 12.hours.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 25.hours.ago)

        mail = DigestMailer.daily_digest(user)
        expect(mail.to).to be_nil
      end

      it "caps at 24 hours even when digest_sent_at allows a larger backlog" do
        user.update!(digest_sent_at: 5.days.ago)
        ep = create(:episode, podcast: podcast, created_at: 2.days.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 2.days.ago)

        mail = DigestMailer.daily_digest(user)
        expect(mail.to).to be_nil
      end
    end

    context "DIG-003: library-centric subject line and copy" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Subject Test", created_at: 1.hour.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "uses featured episode subject line format" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.subject).to include("My Podcast: Subject Test")
      end

      it "does not use subscription-centric subject wording" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.subject).not_to include("podcasts this morning")
      end

      it "uses library-centric heading in HTML body" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.html_part.body.to_s).not_to include("Your podcasts this morning")
      end

      it "uses library-centric heading in text body" do
        mail = DigestMailer.daily_digest(user)
        expect(mail.text_part.body.to_s).not_to include("Your podcasts this morning")
      end
    end

    context "DIG-004: NullMail when no library episodes match" do
      it "returns NullMail when only inbox episodes exist" do
        ep = create(:episode, podcast: podcast, created_at: 1.hour.ago)
        create(:user_episode, user: user, episode: ep, location: :inbox)

        mail = DigestMailer.daily_digest(user)
        expect(mail.to).to be_nil
      end

      it "returns NullMail when library episodes are not ready" do
        ep = create(:episode, podcast: podcast, created_at: 1.hour.ago)
        create(:user_episode, :in_library, user: user, episode: ep, processing_status: :pending)

        mail = DigestMailer.daily_digest(user)
        expect(mail.to).to be_nil
      end
    end

    context "since race protection" do
      it "instance fallback uses captured since parameter, not bumped digest_sent_at" do
        ep = create(:episode, podcast: podcast, title: "Race Protected", created_at: 3.hours.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)

        since = [ user.digest_sent_at, 24.hours.ago ].compact.max
        mail = DigestMailer.daily_digest(user, since)

        user.update!(digest_sent_at: Time.current)
        Thread.current[:digest_mailer_data] = nil

        expect(mail.html_part.body.to_s).to include("Race Protected")
      end
    end

    context "both query sites use shared scope" do
      let!(:episode) do
        ep = create(:episode, podcast: podcast, title: "Shared Scope Test", created_at: 3.hours.ago)
        create(:summary, episode: ep)
        ue = create(:user_episode, :ready, user: user, episode: ep)
        ue.update_column(:updated_at, 1.hour.ago)
        ep
      end

      it "class method and instance fallback produce the same episodes" do
        since = [ user.digest_sent_at, 24.hours.ago ].compact.max

        mail1 = DigestMailer.daily_digest(user, since)
        body1 = mail1.html_part.body.to_s

        Thread.current[:digest_mailer_data] = nil
        mail2 = DigestMailer.daily_digest(user, since)
        Thread.current[:digest_mailer_data] = nil
        body2 = mail2.html_part.body.to_s

        expect(body1).to include("Shared Scope Test")
        expect(body2).to include("Shared Scope Test")
      end
    end
  end
end
