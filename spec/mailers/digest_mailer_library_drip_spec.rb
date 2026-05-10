require "rails_helper"

# Specs for SN-17 / M3 — DigestMailer library-drip composition.
#
# Covers:
#   SEL-004: compact list = next 5 eligible episodes after the featured one (same ordering)
#   SEL-005: NullMail when zero eligible
#   SEL-007: compact may repeat across days until featured
#   TRK-003: featured/compact timestamps written inside Mailer class method
#   TRK-004: stamping wrapped in same DB transaction as EmailEvent creation
#   VAL-001: a user is never featured the same episode twice across consecutive sends
#   Deliver_later determinism via featured_episode_id + recent_episode_ids kwargs
#   No flag branching — single code path
RSpec.describe DigestMailer, "#daily_digest — library-drip", type: :mailer do
  let(:user) { create(:user, email: "drip@example.com", digest_enabled: true) }
  let(:podcast) { create(:podcast, title: "Drip Podcast") }

  # Helper: create an unfeatured library+ready UserEpisode with a Summary, returning the Episode.
  def create_eligible_episode(title:, published_at: 1.day.ago)
    ep = create(:episode, podcast: podcast, title: title, published_at: published_at)
    create(:summary, episode: ep)
    ue = create(:user_episode, :ready, user: user, episode: ep)
    ue.update_columns(digest_featured_at: nil, digest_last_appeared_at: nil)
    ep
  end

  describe "SEL-005: NullMail when zero eligible episodes" do
    it "returns NullMail when the user has no library episodes at all" do
      mail = DigestMailer.daily_digest(user)

      expect(mail).to be_a(ActionMailer::Base::NullMail)
    end

    it "returns NullMail when every library episode has digest_featured_at set" do
      ep = create(:episode, podcast: podcast)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: 1.day.ago)

      mail = DigestMailer.daily_digest(user)

      expect(mail).to be_a(ActionMailer::Base::NullMail)
    end

    it "does not write any EmailEvents when returning NullMail" do
      ep = create(:episode, podcast: podcast)
      create(:summary, episode: ep)
      ue = create(:user_episode, :ready, user: user, episode: ep)
      ue.update_columns(digest_featured_at: 1.day.ago)

      expect { DigestMailer.daily_digest(user) }.not_to change(EmailEvent, :count)
    end
  end

  describe "SEL-004: featured + 5 compact composition" do
    it "renders the newest published episode as featured" do
      _older = create_eligible_episode(title: "Old", published_at: 30.days.ago)
      newest = create_eligible_episode(title: "Brand New", published_at: 1.hour.ago)

      mail = DigestMailer.daily_digest(user)

      expect(mail.subject).to include("Brand New")
    end

    it "renders the next 5 eligible episodes in published_at DESC, id DESC order as compact" do
      # Create 7 eligible episodes; only featured + 5 compact should appear (7th is omitted).
      eligible = 7.times.map do |i|
        create_eligible_episode(title: "Episode #{i}", published_at: (i + 1).days.ago)
      end

      mail = DigestMailer.daily_digest(user)
      body = mail.html_part.body.to_s

      # Episode 0 (newest) should be featured. Episodes 1..5 should appear as compact.
      # Episode 6 (oldest) should be omitted (only 6 total are rendered).
      expect(body).to include("Episode 0")
      (1..5).each { |i| expect(body).to include("Episode #{i}") }
      expect(body).not_to include("Episode 6")
    end

    it "renders a featured episode with fewer than 5 compact when only N eligible (N < 6)" do
      featured = create_eligible_episode(title: "Featured", published_at: 1.day.ago)
      compact1 = create_eligible_episode(title: "Compact A", published_at: 2.days.ago)
      compact2 = create_eligible_episode(title: "Compact B", published_at: 3.days.ago)

      mail = DigestMailer.daily_digest(user)
      body = mail.html_part.body.to_s

      expect(body).to include("Featured")
      expect(body).to include("Compact A")
      expect(body).to include("Compact B")
    end

    it "renders only the featured (no compact section) when exactly 1 eligible" do
      create_eligible_episode(title: "Solo Episode", published_at: 1.hour.ago)

      mail = DigestMailer.daily_digest(user)

      expect(mail.subject).to include("Solo Episode")
      expect(mail.subject).not_to include("more)")
    end
  end

  describe "TRK-003: featured-on-send stamping inside the Mailer class method" do
    it "sets digest_featured_at on the featured episode's UserEpisode when daily_digest is called" do
      ep = create_eligible_episode(title: "Featured Now", published_at: 1.hour.ago)
      ue = UserEpisode.find_by!(user: user, episode: ep)

      freeze_time do
        DigestMailer.daily_digest(user)

        expect(ue.reload.digest_featured_at).to be_within(1.second).of(Time.current)
      end
    end

    it "sets digest_last_appeared_at on each compact episode's UserEpisode" do
      featured = create_eligible_episode(title: "Featured", published_at: 1.hour.ago)
      compact_eps = 2.times.map do |i|
        create_eligible_episode(title: "Compact #{i}", published_at: (i + 2).hours.ago)
      end

      freeze_time do
        DigestMailer.daily_digest(user)

        compact_eps.each do |ep|
          ue = UserEpisode.find_by!(user: user, episode: ep)
          expect(ue.reload.digest_last_appeared_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    it "does NOT set digest_featured_at on compact episodes (only on the featured one)" do
      featured = create_eligible_episode(title: "Featured", published_at: 1.hour.ago)
      compact = create_eligible_episode(title: "Compact", published_at: 2.hours.ago)

      DigestMailer.daily_digest(user)

      compact_ue = UserEpisode.find_by!(user: user, episode: compact)
      expect(compact_ue.reload.digest_featured_at).to be_nil
    end
  end

  describe "TRK-004: transaction wraps EmailEvent creation + featured stamping" do
    it "rolls back digest_featured_at when EmailEvent creation fails inside the transaction" do
      ep = create_eligible_episode(title: "Trx Featured", published_at: 1.hour.ago)
      ue = UserEpisode.find_by!(user: user, episode: ep)

      # Force EmailEvent.create! / find_or_create_by! to raise — the surrounding
      # transaction must roll back the digest_featured_at stamp as well.
      allow(EmailEvent).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordInvalid.new(EmailEvent.new))

      expect {
        begin
          DigestMailer.daily_digest(user)
        rescue ActiveRecord::RecordInvalid
          # expected — bubble the error after rollback
        end
      }.not_to change { ue.reload.digest_featured_at }

      expect(ue.reload.digest_featured_at).to be_nil
    end

    it "does not create EmailEvent rows when the transaction rolls back" do
      ep = create_eligible_episode(title: "Trx Episode", published_at: 1.hour.ago)

      allow(EmailEvent).to receive(:find_or_create_by!)
        .and_wrap_original do |original, *args, **kwargs|
          # Allow the first call (open event) to succeed, fail on the second (click)
          # so we exercise the partial-failure rollback path.
          @call_count ||= 0
          @call_count += 1
          if @call_count >= 2
            raise ActiveRecord::RecordInvalid.new(EmailEvent.new)
          else
            original.call(*args, **kwargs)
          end
        end

      expect {
        begin
          DigestMailer.daily_digest(user)
        rescue ActiveRecord::RecordInvalid
          # expected
        end
      }.not_to change(EmailEvent, :count)
    end
  end

  describe "VAL-001: no re-feature across consecutive sends" do
    it "picks a different featured episode on the second invocation" do
      ep1 = create_eligible_episode(title: "First", published_at: 1.day.ago)
      ep2 = create_eligible_episode(title: "Second", published_at: 2.days.ago)

      mail1 = DigestMailer.daily_digest(user)
      first_subject = mail1.subject

      # Simulate a fresh "next morning" send — clear thread-local so the worker
      # path is exercised (or class method runs again from scratch).
      Thread.current[:digest_mailer_data] = nil

      mail2 = DigestMailer.daily_digest(user)
      second_subject = mail2.subject

      expect(first_subject).to include("First")
      expect(second_subject).to include("Second")
      expect(second_subject).not_to eq(first_subject)
    end

    it "the featured episode from day 1 does not reappear as featured on day 2" do
      ep1 = create_eligible_episode(title: "Day1Feature", published_at: 1.day.ago)
      ep2 = create_eligible_episode(title: "Day2Feature", published_at: 2.days.ago)

      DigestMailer.daily_digest(user)
      Thread.current[:digest_mailer_data] = nil

      mail2 = DigestMailer.daily_digest(user)

      expect(mail2.subject).not_to include("Day1Feature")
    end
  end

  describe "SEL-007: compact may repeat across days until featured" do
    it "an episode that appeared in compact yesterday MAY appear again today (until it is featured)" do
      # Day 1: featured = newest, compact includes "RepeatMe"
      newest = create_eligible_episode(title: "Newest", published_at: 1.day.ago)
      repeat_me = create_eligible_episode(title: "RepeatMe", published_at: 5.days.ago)

      mail1 = DigestMailer.daily_digest(user)
      expect(mail1.html_part.body.to_s).to include("RepeatMe")

      Thread.current[:digest_mailer_data] = nil

      # Day 2: featured = "Newest" was featured day 1 — drops out. Now the next
      # newest unfeatured is "RepeatMe", which should appear (could be featured now,
      # could remain in compact if a newer un-featured exists).
      mail2 = DigestMailer.daily_digest(user)
      expect(mail2.html_part.body.to_s).to include("RepeatMe")
    end
  end

  describe "deliver_later determinism: featured_episode_id + recent_episode_ids kwargs" do
    it "the class method signature accepts featured_episode_id and recent_episode_ids kwargs" do
      method = DigestMailer.method(:daily_digest)
      param_names = method.parameters.map { |_kind, name| name }

      expect(param_names).to include(:featured_episode_id)
      expect(param_names).to include(:recent_episode_ids)
    end

    it "retains :since as a no-op kwarg for backwards compatibility (per GP-1)" do
      method = DigestMailer.method(:daily_digest)
      param_names = method.parameters.map { |_kind, name| name }

      expect(param_names).to include(:since)
    end

    it "the instance method loads the featured episode by featured_episode_id when given" do
      featured  = create_eligible_episode(title: "DeterministicFeatured", published_at: 1.hour.ago)
      compact_a = create_eligible_episode(title: "DeterministicCompactA", published_at: 2.hours.ago)
      compact_b = create_eligible_episode(title: "DeterministicCompactB", published_at: 3.hours.ago)

      # Eager class call — picks featured + compacts and stamps digest_featured_at.
      mail = DigestMailer.daily_digest(user)

      # Simulate the deliver_later worker boundary: clear thread-local so the
      # instance method must rely on the kwargs serialised onto the message.
      Thread.current[:digest_mailer_data] = nil

      body = mail.html_part.body.to_s
      expect(body).to include("DeterministicFeatured")
      expect(body).to include("DeterministicCompactA")
      expect(body).to include("DeterministicCompactB")
    end

    it "falls back to re-querying eligible_for_drip when featured_episode_id and recent_episode_ids are nil" do
      ep = create_eligible_episode(title: "FallbackEpisode", published_at: 1.hour.ago)

      # Invoke the instance method directly with nil kwargs, mimicking an old
      # serialised job in the queue at deploy time (the architecture's GP-1
      # backwards-compat case).
      Thread.current[:digest_mailer_data] = nil
      mail = DigestMailer.daily_digest(user, since: nil, featured_episode_id: nil, recent_episode_ids: nil)

      expect(mail.html_part.body.to_s).to include("FallbackEpisode")
    end
  end

  describe "subject line (UI-004 — unchanged)" do
    it "uses the existing podcast: episode (+N more) format" do
      featured = create_eligible_episode(title: "SubjectFeatured", published_at: 1.hour.ago)
      compact  = create_eligible_episode(title: "SubjectCompact",  published_at: 2.hours.ago)

      mail = DigestMailer.daily_digest(user)

      expect(mail.subject).to include("Drip Podcast: SubjectFeatured")
      expect(mail.subject).to include("(+1 more)")
    end
  end

  describe "M4: body copy (library-drip framing)" do
    let!(:featured) { create_eligible_episode(title: "CopyFeatured", published_at: 1.hour.ago) }

    context "UI-003: no time-of-day phrases in the body" do
      it "does not include 'Today's episodes' or 'Yesterday's transcriptions' in the HTML body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).not_to match(/today'?s episodes/i)
        expect(body).not_to match(/yesterday'?s transcriptions/i)
        expect(body).not_to match(/last 24 hours/i)
      end

      it "does not include 'Today's episodes' or similar in the text body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).not_to match(/today'?s episodes/i)
        expect(body).not_to match(/yesterday'?s transcriptions/i)
        expect(body).not_to match(/last 24 hours/i)
      end
    end

    context "UI-005: body copy reflects library-drip framing" do
      it "includes a phrase rooted in 'library' or 'next from' framing in the HTML body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.html_part.body.to_s

        expect(body).to match(/library|next from|from your/i)
      end

      it "includes a phrase rooted in 'library' or 'next from' framing in the text body" do
        mail = DigestMailer.daily_digest(user)
        body = mail.text_part.body.to_s

        expect(body).to match(/library|next from|from your/i)
      end
    end

    context "UI-001 / UI-002: featured + compact layout preserved" do
      let!(:compact) { create_eligible_episode(title: "CopyCompact", published_at: 2.hours.ago) }

      it "renders 'Read in app' for the featured episode (SN-5 layout preserved)" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body.to_s).to include("Read in app")
      end

      it "renders 'Read full summary' or equivalent for compact items (SN-5 layout preserved)" do
        mail = DigestMailer.daily_digest(user)

        expect(mail.html_part.body.to_s).to include("Read full summary").or include("Listen")
      end
    end

    context "old-episode rendering" do
      it "renders gracefully when the featured episode's published_at is months old" do
        # Wipe any other eligible episodes so we control the featured pick.
        UserEpisode.update_all(digest_featured_at: 1.day.ago)

        old_ep = create_eligible_episode(title: "AncientEpisode", published_at: 6.months.ago)

        mail = DigestMailer.daily_digest(user)

        expect(mail.subject).to include("AncientEpisode")
        expect(mail.html_part.body.to_s).to include("AncientEpisode")
      end
    end
  end
end
