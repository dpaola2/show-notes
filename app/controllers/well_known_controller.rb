class WellKnownController < ActionController::Base
  def apple_app_site_association
    file = Rails.root.join("public/.well-known/apple-app-site-association")
    render json: File.read(file)
  end
end
