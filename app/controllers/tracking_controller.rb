class TrackingController < ApplicationController
  skip_before_action :require_authentication

  TRANSPARENT_GIF = Base64.decode64(
    "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
  ).freeze

  def click
    event = EmailEvent.find_by(token: params[:token])

    if event
      event.trigger!(request: request)
      capture_email_event("email_link_clicked", event)
      redirect_to destination_for(event), allow_other_host: false
    else
      redirect_to root_path
    end
  end

  def pixel
    event = EmailEvent.find_by(token: params[:token])
    if event
      event.trigger!(request: request)
      capture_email_event("email_opened", event)
    end

    send_data TRANSPARENT_GIF, type: "image/gif", disposition: "inline"
  end

  private

  # Email recipients are not logged in, so capture against the recipient user id
  # directly rather than the anonymous request session.
  def capture_email_event(name, event)
    Analytics.capture(
      distinct_id: event.user_id,
      event: name,
      properties: {
        platform: "email",
        link_type: event.link_type,
        episode_id: event.episode_id,
        digest_date: event.digest_date
      }
    )
  end

  def destination_for(event)
    case event.link_type
    when "summary"
      episode_path(event.episode)
    when "listen"
      episode_path(event.episode, anchor: "audio")
    else
      root_path
    end
  end
end
