class LandingController < ApplicationController
  skip_before_action :require_authentication, only: [ :show ]
  layout "landing"

  # Public marketing landing page. Logged-in users go straight to the app.
  # flash.keep preserves any notice (e.g. "Welcome back!" set during magic-link
  # verify, which redirects to root) across this extra hop to the inbox.
  def show
    if logged_in?
      flash.keep
      redirect_to inbox_index_path
    end
  end
end
