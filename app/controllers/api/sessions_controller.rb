class Api::SessionsController < Api::BaseController
  skip_before_action :require_api_authentication, only: [ :create, :verify ]

  def create
    email = params[:email]&.downcase&.strip
    user = User.find_or_create_by!(email: email)
    token = user.generate_magic_token!
    source = params[:source]&.to_sym || :web
    UserMailer.magic_link(user, token, source: source).tap do |mail|
      mail.deliver_later
      mail.deliver_now if Rails.env.test?
    end

    render json: { message: "Check your email for a sign-in link" }
  end

  def verify
    magic_token = params[:token]
    user = User.find_by(magic_token: magic_token)

    if user&.magic_token_valid?(magic_token)
      user.clear_magic_token!
      _api_token, plaintext = ApiToken.generate_for(user)
      render json: { token: plaintext }
    else
      render json: { error: "Link expired or invalid" }, status: :unauthorized
    end
  end

  def destroy
    current_api_token.update!(token_digest: "revoked:#{current_api_token.token_digest}")
    render json: { message: "Logged out" }
  end
end
