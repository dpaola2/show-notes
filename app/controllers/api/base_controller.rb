class Api::BaseController < ActionController::Base
  include Pagy::Method

  skip_forgery_protection

  before_action :require_api_authentication

  private

  def current_user
    @current_user ||= current_api_token&.user
  end

  def current_api_token
    @current_api_token ||= authenticate_bearer_token
  end

  def authenticate_bearer_token
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    api_token = ApiToken.find_by_plaintext(token)
    api_token&.touch_last_used!
    api_token
  end

  def require_api_authentication
    unless current_user
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def render_not_found
    render json: { error: "Not found" }, status: :not_found
  end
end
