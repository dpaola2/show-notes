class Api::TrackingController < Api::BaseController
  def click
    event = EmailEvent.find_by!(token: params[:token])

    if event.user_id != current_user.id
      render_not_found
      return
    end

    event.trigger!(request: request)

    render json: { episode_id: event.episode_id, link_type: event.link_type }
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
