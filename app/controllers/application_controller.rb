class ApplicationController < ActionController::Base
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Require authentication for all actions by default
  before_action :require_authentication

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def require_authentication
    unless current_user
      session[:return_to] = request.original_url if request.get?
      redirect_to login_path, alert: "Please sign in to continue"
    end
  end

  def logged_in?
    current_user.present?
  end
  helper_method :logged_in?
end
