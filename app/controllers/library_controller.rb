class LibraryController < ApplicationController
  def index
    @user_episodes = current_user.user_episodes
      .in_library
      .includes(episode: [ :podcast, :summary ])
      .order("episodes.published_at DESC")
  end

  def show
    @user_episode = current_user.user_episodes.find(params[:id])
    @episode = @user_episode.episode
  end

  def archive
    user_episode = current_user.user_episodes.find(params[:id])
    user_episode.move_to_archive!
    redirect_to library_index_path, notice: "Moved to Archive"
  end

  def regenerate
    user_episode = current_user.user_episodes.find(params[:id])
    # Delete existing summary and re-process
    user_episode.episode.summary&.destroy
    user_episode.update!(
      processing_status: :summarizing,
      retry_count: 0,
      next_retry_at: nil,
      processing_error: nil
    )
    ProcessEpisodeJob.perform_later(user_episode.id)
    redirect_to library_path(user_episode), notice: "Regenerating summary..."
  end

end
