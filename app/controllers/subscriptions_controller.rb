class SubscriptionsController < ApplicationController
  before_action :require_current_user

  def index
    @subscriptions = current_user.subscriptions.includes(:podcast).order(created_at: :desc)
  end

  private

  def require_current_user
    unless current_user
      redirect_to root_path, alert: "Please sign in to continue"
    end
  end

  def current_user
    # TODO: Replace with real authentication in Phase 3
    @current_user ||= User.first
  end
  helper_method :current_user
end
