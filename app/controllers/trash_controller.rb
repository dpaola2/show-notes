class TrashController < ApplicationController
  before_action :require_current_user

  def index
    @user_episodes = current_user.user_episodes
      .in_trash
      .includes(episode: :podcast)
      .order(trashed_at: :desc)
  end

  def restore
    user_episode = current_user.user_episodes.find(params[:id])
    user_episode.move_to_inbox!
    redirect_to trash_index_path, notice: "Restored to Inbox"
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
