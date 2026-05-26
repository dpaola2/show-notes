class LegalController < ApplicationController
  skip_before_action :require_authentication

  def privacy
    render layout: "public"
  end

  def support
    render layout: "public"
  end
end
