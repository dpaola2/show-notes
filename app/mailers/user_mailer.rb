class UserMailer < ApplicationMailer
  def magic_link(user, token)
    @user = user
    @token = token
    @magic_link_url = verify_magic_link_url(token: token)

    mail(
      to: user.email,
      subject: "Sign in to Show Notes"
    )
  end
end
