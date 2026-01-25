class DigestMailer < ApplicationMailer
  helper ApplicationHelper

  def daily_digest(user)
    @user = user
    @inbox_episodes = user.user_episodes
      .in_inbox
      .includes(episode: :podcast)
      .order("episodes.published_at DESC")
      .limit(5)

    @library_episodes = user.user_episodes
      .in_library
      .ready
      .includes(episode: [ :podcast, :summary ])
      .where("user_episodes.updated_at > ?", 2.days.ago)
      .order(updated_at: :desc)
      .limit(2)

    @inbox_count = user.user_episodes.in_inbox.count
    @date = Date.current.strftime("%b %d")

    mail(
      to: user.email,
      subject: "Your Daily Podcast Digest - #{@date}"
    )
  end
end
