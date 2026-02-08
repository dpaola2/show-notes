class DigestMailer < ApplicationMailer
  helper ApplicationHelper

  # Eagerly create tracking events when the class method is called.
  # ActionMailer's MessageDelivery is lazy — the instance method only
  # runs when the message is rendered. Tests expect EmailEvent records
  # to exist after calling DigestMailer.daily_digest(user), so we
  # pre-create them here and stash them in a thread-local for the
  # instance method to pick up during rendering.
  def self.daily_digest(user)
    digest_date = Date.current.to_s
    since = user.digest_sent_at || 1.day.ago

    episodes_by_show = Episode
      .joins(podcast: :subscriptions)
      .where(subscriptions: { user_id: user.id })
      .where("episodes.created_at > ?", since)
      .includes(:podcast, :summary)
      .order("podcasts.title ASC, episodes.published_at DESC")
      .group_by(&:podcast)

    episode_count = episodes_by_show.values.flatten.size
    return ActionMailer::Base::NullMail.new if episode_count.zero?

    open_event = EmailEvent.create!(
      user: user, token: SecureRandom.urlsafe_base64(16),
      event_type: "open", digest_date: digest_date
    )
    click_events = {}
    episodes_by_show.each_value do |episodes|
      episodes.each do |episode|
        click_events[episode.id] = {
          summary: EmailEvent.create!(
            user: user, token: SecureRandom.urlsafe_base64(16),
            event_type: "click", link_type: "summary", episode: episode, digest_date: digest_date
          ),
          listen: EmailEvent.create!(
            user: user, token: SecureRandom.urlsafe_base64(16),
            event_type: "click", link_type: "listen", episode: episode, digest_date: digest_date
          )
        }
      end
    end

    Thread.current[:digest_mailer_data] = {
      episodes_by_show: episodes_by_show,
      open_event: open_event,
      click_events: click_events
    }

    super(user)
  end

  def daily_digest(user)
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
      since = user.digest_sent_at || 1.day.ago
      @episodes_by_show = Episode
        .joins(podcast: :subscriptions)
        .where(subscriptions: { user_id: user.id })
        .where("episodes.created_at > ?", since)
        .includes(:podcast, :summary)
        .order("podcasts.title ASC, episodes.published_at DESC")
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
      subject: "Your podcasts this morning — #{@episode_count} new episode#{'s' unless @episode_count == 1}"
    )
  end
end
