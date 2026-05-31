class LandingController < ApplicationController
  skip_before_action :require_authentication, only: [ :show ]
  layout "landing"

  # Public marketing landing page. Logged-in users go straight to the app.
  # flash.keep preserves any notice (e.g. "Welcome back!" set during magic-link
  # verify, which redirects to root) across this extra hop to the inbox.
  def show
    return unless logged_in?

    flash.keep
    # New users (no subscriptions yet) go to onboarding; everyone else to the app.
    redirect_to(current_user.subscriptions.any? ? inbox_index_path : onboarding_path)
  end
end
