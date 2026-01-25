class TrashController < ApplicationController
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
end
