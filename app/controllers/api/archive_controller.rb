class Api::ArchiveController < Api::BaseController
  def index
    @pagy, @user_episodes = pagy(
      current_user.user_episodes
        .in_archive
        .includes(episode: [ :podcast, :summary ])
        .order("episodes.published_at DESC")
    )
  rescue Pagy::OverflowError
    @pagy = Pagy.new(count: 0, page: 1)
    @user_episodes = current_user.user_episodes.none
  end

  def restore
    user_episode = current_user.user_episodes.find(params[:id])
    user_episode.restore_from_archive!
    render json: { message: "Restored to library" }
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
