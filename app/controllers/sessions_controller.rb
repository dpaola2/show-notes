class SessionsController < ApplicationController
  layout "sessions", only: [ :new, :create, :sent ]
  skip_before_action :require_authentication, only: [ :new, :create, :sent, :verify ]

  def new
    # Show login form
  end

  def create
    @email = params[:email]&.downcase&.strip

    if @email.blank?
      flash.now[:alert] = "Please enter your email address"
      render :new, status: :unprocessable_entity
      return
    end

    user = User.find_or_create_by!(email: @email)
    token = user.generate_magic_token!

    UserMailer.magic_link(user, token).deliver_later

    redirect_to magic_link_sent_path, notice: "Check your email for a login link"
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Invalid email address"
    render :new, status: :unprocessable_entity
  end

  def sent
    # Show "check your email" page
  end

  def verify
    token = params[:token]

    if token.blank?
      redirect_to login_path, alert: "Invalid or missing token"
      return
    end

    user = User.find_by(magic_token: token)

    if user&.magic_token_valid?(token)
      user.clear_magic_token!
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome back!"
    else
      redirect_to login_path, alert: "This link has expired or is invalid. Please request a new one."
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "You have been logged out"
  end
end
