class Api::LibraryController < Api::BaseController
  def index
    sort_direction = params[:sort] == "oldest" ? "ASC" : "DESC"
    @pagy, @user_episodes = pagy(
      current_user.user_episodes
        .in_library
        .includes(episode: [ :podcast, :summary ])
        .order("episodes.published_at #{sort_direction}")
    )
  rescue Pagy::OverflowError
    @pagy = Pagy.new(count: 0, page: 1)
    @user_episodes = current_user.user_episodes.none
  end

  def show
    @user_episode = current_user.user_episodes
      .includes(episode: [ :podcast, :summary ])
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def archive
    user_episode = current_user.user_episodes.find(params[:id])
    user_episode.move_to_archive!
    render json: { message: "Archived" }
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
