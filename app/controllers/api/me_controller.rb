class Api::MeController < Api::BaseController
  # Returns the authenticated user's canonical id so native clients can use it
  # as the PostHog distinct_id — the same id the server uses — unifying
  # web + iOS analytics under one identity.
  def show
    render json: { id: current_user.id, email: current_user.email }
  end
end
