class SignupNotificationMailer < ApplicationMailer
  RECIPIENTS = [
    "dpaola2@gmail.com",
    "dpaola2-ceo@agentmail.to"
  ].freeze

  def new_signup(user)
    @user = user
    @signed_up_at = user.created_at

    mail(
      to: RECIPIENTS,
      subject: "New Show Notes signup: #{user.email}"
    )
  end
end
