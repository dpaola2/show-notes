class DigestMailer < ApplicationMailer
  helper ApplicationHelper

  # Library-drip composition. Picks the next-unfeatured episodes for the user
  # from the entire library (no time window), stamps `digest_featured_at` on
  # the featured pick and `digest_last_appeared_at` on each compact pick in
  # the same DB transaction as EmailEvent creation, and serialises the chosen
  # episode IDs as Mailer kwargs so the deliver_later worker is deterministic.
  #
  # When called from `SendDailyDigestJob`, `featured_episode_id` and
  # `recent_episode_ids` are passed in (the job pre-fetched them via the
  # eligibility check). When called directly (specs, manual invocation), the
  # class method does its own `Episode.eligible_for_drip(user).limit(6)`
  # lookup.
  #
  # `since:` is retained as a no-op kwarg per GP-1, to avoid breaking older
  # serialized Solid Queue jobs in flight at deploy time. It is removed in a
  # follow-up release.
  def self.daily_digest(user, since: nil, featured_episode_id: nil, recent_episode_ids: nil)
    digest_date = Date.current.to_s

    featured_episode, recent_episodes = pick_episodes(user, featured_episode_id, recent_episode_ids)

    return ActionMailer::Base::NullMail.new if featured_episode.nil?

    open_event = nil
    click_events = {}

    ActiveRecord::Base.transaction do
      open_event = find_or_create_event!(
        user: user, event_type: "open", digest_date: digest_date
      )

      # Featured episode: only summary click event (single "Read in app" link)
      click_events[featured_episode.id] = {
        summary: find_or_create_event!(
          user: user, event_type: "click", link_type: "summary",
          episode: featured_episode, digest_date: digest_date
        )
      }
      # Recent episodes: summary + listen click events
      recent_episodes.each do |episode|
        click_events[episode.id] = {
          summary: find_or_create_event!(
            user: user, event_type: "click", link_type: "summary",
            episode: episode, digest_date: digest_date
          ),
          listen: find_or_create_event!(
            user: user, event_type: "click", link_type: "listen",
            episode: episode, digest_date: digest_date
          )
        }
      end

      stamp_at = Time.current
      featured_ue = UserEpisode.find_by!(user_id: user.id, episode_id: featured_episode.id)
      featured_ue.mark_digest_featured!(at: stamp_at)
      recent_episodes.each do |episode|
        compact_ue = UserEpisode.find_by!(user_id: user.id, episode_id: episode.id)
        compact_ue.mark_digest_compact_appearance!(at: stamp_at)
      end
    end

    Thread.current[:digest_mailer_data] = {
      featured_episode: featured_episode,
      recent_episodes: recent_episodes,
      open_event: open_event,
      click_events: click_events
    }

    super(
      user,
      since: since,
      featured_episode_id: featured_episode.id,
      recent_episode_ids: recent_episodes.map(&:id)
    )
  end

  def self.find_or_create_event!(**attrs)
    EmailEvent.find_or_create_by!(attrs) do |e|
      e.token = SecureRandom.urlsafe_base64(16)
    end
  end
  private_class_method :find_or_create_event!

  # Returns [featured_episode, recent_episodes] tuple. When IDs are supplied,
  # loads by ID (no eligible_for_drip call). Otherwise queries
  # `Episode.eligible_for_drip(user).limit(6)`.
  def self.pick_episodes(user, featured_episode_id, recent_episode_ids)
    if featured_episode_id
      featured = Episode.preload(:podcast, :summary).find_by(id: featured_episode_id)
      ids = Array(recent_episode_ids)
      compacts = if ids.any?
        Episode.preload(:podcast, :summary).where(id: ids).index_by(&:id).values_at(*ids).compact
      else
        []
      end
      [ featured, compacts ]
    else
      all_episodes = Episode.eligible_for_drip(user).limit(6).to_a
      [ all_episodes.first, all_episodes[1..5] || [] ]
    end
  end
  private_class_method :pick_episodes

  def daily_digest(user, since: nil, featured_episode_id: nil, recent_episode_ids: nil)
    @user = user
    @date = Date.current.strftime("%A, %B %-d")

    data = Thread.current[:digest_mailer_data]
    Thread.current[:digest_mailer_data] = nil

    if data
      @featured_episode = data[:featured_episode]
      @recent_episodes = data[:recent_episodes]
      @open_event = data[:open_event]
      @click_events = data[:click_events]
    else
      # Fallback for deliver_later (runs in a worker thread, no thread-local).
      # Prefer the IDs serialised onto the message (deterministic) — fall back
      # to a fresh `eligible_for_drip` re-query when both kwargs are nil
      # (legacy serialised jobs draining at deploy time, per GP-1).
      load_episodes_from_args_or_requery(user, featured_episode_id, recent_episode_ids)

      digest_date = Date.current.to_s
      @open_event = EmailEvent.find_by(user: user, event_type: "open", digest_date: digest_date)
      @click_events = {}
      ([ @featured_episode ] + @recent_episodes).compact.each do |episode|
        summary_event = EmailEvent.find_by(user: user, event_type: "click",
          link_type: "summary", episode: episode, digest_date: digest_date)
        listen_event = EmailEvent.find_by(user: user, event_type: "click",
          link_type: "listen", episode: episode, digest_date: digest_date)
        @click_events[episode.id] = { summary: summary_event, listen: listen_event }.compact
      end
    end

    @total_count = 1 + @recent_episodes.size

    subject = "#{@featured_episode.podcast.title}: #{@featured_episode.title}"
    subject += " (+#{@recent_episodes.size} more)" if @recent_episodes.any?

    mail(to: user.email, subject: subject)
  end

  private

  def load_episodes_from_args_or_requery(user, featured_episode_id, recent_episode_ids)
    if featured_episode_id.present?
      @featured_episode = Episode.preload(:podcast, :summary).find_by(id: featured_episode_id)
      ids = Array(recent_episode_ids)
      @recent_episodes = ids.any? ? Episode.preload(:podcast, :summary).where(id: ids).index_by(&:id).values_at(*ids).compact : []
    end

    return if @featured_episode

    all_episodes = Episode.eligible_for_drip(user).limit(6).to_a
    @featured_episode = all_episodes.first
    @recent_episodes = all_episodes[1..5] || []
  end
end
