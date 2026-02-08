class TrackingController < ApplicationController
  skip_before_action :require_authentication

  TRANSPARENT_GIF = Base64.decode64(
    "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
  ).freeze

  def click
    event = EmailEvent.find_by(token: params[:token])

    if event
      event.trigger!(request: request)
      redirect_to destination_for(event), allow_other_host: false
    else
      redirect_to root_path
    end
  end

  def pixel
    event = EmailEvent.find_by(token: params[:token])
    event&.trigger!(request: request)

    send_data TRANSPARENT_GIF, type: "image/gif", disposition: "inline"
  end

  private

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
