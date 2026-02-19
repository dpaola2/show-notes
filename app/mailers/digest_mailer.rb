class DigestMailer < ApplicationMailer
  helper ApplicationHelper

  # Eagerly create tracking events when the class method is called.
  # ActionMailer's MessageDelivery is lazy — the instance method only
  # runs when the message is rendered. Tests expect EmailEvent records
  # to exist after calling DigestMailer.daily_digest(user), so we
  # pre-create them here and stash them in a thread-local for the
  # instance method to pick up during rendering.
  #
  # The `since` parameter captures the episode cutoff time. It is passed
  # through to `super` so that deliver_later serialises it as a mailer
  # argument. When the worker re-invokes this class method, `since` is
  # already set, protecting against the race where `digest_sent_at` was
  # bumped between scheduling and delivery.
  def self.daily_digest(user, since = nil)
    since ||= [ user.digest_sent_at, 24.hours.ago ].compact.max
    digest_date = Date.current.to_s

    all_episodes = Episode.library_ready_since(user, since).to_a
    featured_episode = all_episodes.first
    recent_episodes = all_episodes[1..5] || []

    return ActionMailer::Base::NullMail.new if featured_episode.nil?

    open_event = find_or_create_event!(
      user: user, event_type: "open", digest_date: digest_date
    )

    click_events = {}
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

    Thread.current[:digest_mailer_data] = {
      featured_episode: featured_episode,
      recent_episodes: recent_episodes,
      open_event: open_event,
      click_events: click_events
    }

    super(user, since)
  end

  def self.find_or_create_event!(**attrs)
    EmailEvent.find_or_create_by!(attrs) do |e|
      e.token = SecureRandom.urlsafe_base64(16)
    end
  end
  private_class_method :find_or_create_event!

  def daily_digest(user, since = nil)
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
      # Fallback for deliver_later (runs in a job, no thread-local).
      # Re-query episodes; events were already created eagerly.
      # Use the passed `since` to avoid reading the already-bumped digest_sent_at.
      since ||= [ user.digest_sent_at, 24.hours.ago ].compact.max
      all_episodes = Episode.library_ready_since(user, since).to_a
      @featured_episode = all_episodes.first
      @recent_episodes = all_episodes[1..5] || []

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
end
