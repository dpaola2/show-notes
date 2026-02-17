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

    episodes_by_show = Episode
      .library_ready_since(user, since)
      .group_by(&:podcast)

    episode_count = episodes_by_show.values.flatten.size
    return ActionMailer::Base::NullMail.new if episode_count.zero?

    open_event = find_or_create_event!(
      user: user, event_type: "open", digest_date: digest_date
    )
    click_events = {}
    episodes_by_show.each_value do |episodes|
      episodes.each do |episode|
        click_events[episode.id] = {
          summary: find_or_create_event!(
            user: user, event_type: "click", link_type: "summary", episode: episode, digest_date: digest_date
          ),
          listen: find_or_create_event!(
            user: user, event_type: "click", link_type: "listen", episode: episode, digest_date: digest_date
          )
        }
      end
    end

    Thread.current[:digest_mailer_data] = {
      episodes_by_show: episodes_by_show,
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
      @episodes_by_show = data[:episodes_by_show]
      @open_event = data[:open_event]
      @click_events = data[:click_events]
    else
      # Fallback for deliver_later (runs in a job, no thread-local).
      # Re-query episodes; events were already created eagerly.
      # Use the passed `since` to avoid reading the already-bumped digest_sent_at.
      since ||= [ user.digest_sent_at, 24.hours.ago ].compact.max
      @episodes_by_show = Episode
        .library_ready_since(user, since)
        .group_by(&:podcast)

      digest_date = Date.current.to_s
      @open_event = EmailEvent.find_by(user: user, event_type: "open", digest_date: digest_date)
      @click_events = {}
      @episodes_by_show.each_value do |episodes|
        episodes.each do |episode|
          @click_events[episode.id] = {
            summary: EmailEvent.find_by(user: user, event_type: "click", link_type: "summary", episode: episode, digest_date: digest_date),
            listen: EmailEvent.find_by(user: user, event_type: "click", link_type: "listen", episode: episode, digest_date: digest_date)
          }
        end
      end
    end

    @episode_count = @episodes_by_show.values.flatten.size

    mail(
      to: user.email,
      subject: "Your library — #{@episode_count} episode#{'s' unless @episode_count == 1} ready"
    )
  end
end
