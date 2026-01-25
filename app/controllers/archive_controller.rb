class ArchiveController < ApplicationController
  before_action :require_current_user

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

  private

  def require_current_user
    unless current_user
      redirect_to root_path, alert: "Please sign in to continue"
    end
  end

  def current_user
    # TODO: Replace with real authentication in Phase 3
    @current_user ||= User.first
  end
  helper_method :current_user
end
