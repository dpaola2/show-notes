class UserMailer < ApplicationMailer
  def magic_link(user, token, source: :web)
    @user = user
    @token = token
    @magic_link_url = if source.to_sym == :ios
      "https://listen.davepaola.com/auth/verify?token=#{token}"
    else
      verify_magic_link_url(token: token)
    end

    mail(
      to: user.email,
      subject: "Sign in to Show Notes"
    )
  end
end
