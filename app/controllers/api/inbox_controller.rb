class Api::InboxController < Api::BaseController
  def index
    @pagy, @user_episodes = pagy(
      current_user.user_episodes
        .in_inbox
        .includes(episode: [:podcast, :summary])
        .order("episodes.published_at DESC")
    )
  rescue Pagy::OverflowError
    @pagy = Pagy.new(count: 0, page: 1)
    @user_episodes = current_user.user_episodes.none
  end

  def add_to_library
    user_episode = current_user.user_episodes.in_inbox.find(params[:id])
    user_episode.move_to_library!
    ProcessEpisodeJob.perform_later(user_episode.id)
    render json: { message: "Added to library" }
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def skip
    user_episode = current_user.user_episodes.in_inbox.find(params[:id])
    user_episode.move_to_trash!
    render json: { message: "Skipped" }
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def retry_processing
    user_episode = current_user.user_episodes.in_inbox.find(params[:id])
    unless user_episode.error?
      render json: { error: "Episode is not in error state" }, status: :unprocessable_entity
      return
    end
    user_episode.retry_processing!
    ProcessEpisodeJob.perform_later(user_episode.id)
    render json: { message: "Retrying" }
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def clear
    count = current_user.user_episodes.in_inbox.count
    current_user.user_episodes.in_inbox.update_all(
      location: "trash",
      trashed_at: Time.current,
      updated_at: Time.current
    )
    render json: { message: "Cleared #{count} episodes" }
  end
end
