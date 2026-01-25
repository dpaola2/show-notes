class ArchiveController < ApplicationController
  def index
    @user_episodes = current_user.user_episodes
      .in_archive
      .includes(episode: [ :podcast, :summary ])
      .order("episodes.published_at DESC")
  end

  def show
    @user_episode = current_user.user_episodes.find(params[:id])
    @episode = @user_episode.episode
  end

  def restore
    user_episode = current_user.user_episodes.find(params[:id])
    user_episode.move_to_library!
    redirect_to archive_index_path, notice: "Restored to Library"
  end

end
