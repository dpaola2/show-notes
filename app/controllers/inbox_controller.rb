class InboxController < ApplicationController
  def index
    @user_episodes = current_user.user_episodes
      .in_inbox
      .includes(episode: :podcast)
      .order("episodes.published_at DESC")
  end

  def create
    episode = Episode.find(params[:episode_id])
    user_episode = current_user.user_episodes.find_or_initialize_by(episode: episode)

    if user_episode.new_record?
      user_episode.location = :inbox
      user_episode.save!
      redirect_back fallback_location: podcasts_path, notice: "Added to Inbox"
    else
      redirect_back fallback_location: podcasts_path, notice: "Episode already in #{user_episode.location.humanize}"
    end
  end

  def add_to_library
    if params[:episode_id].present?
      # Adding from Show Archive (new episode)
      episode = Episode.find(params[:episode_id])
      user_episode = current_user.user_episodes.find_or_initialize_by(episode: episode)

      if user_episode.new_record? || !user_episode.library?
        user_episode.move_to_library!
        ProcessEpisodeJob.perform_later(user_episode.id)
        redirect_back fallback_location: library_index_path, notice: "Added to Library. Processing will begin shortly."
      else
        redirect_back fallback_location: library_index_path, notice: "Episode already in Library"
      end
    else
      # Moving from Inbox
      user_episode = current_user.user_episodes.find(params[:id])
      user_episode.move_to_library!
      ProcessEpisodeJob.perform_later(user_episode.id)
      redirect_to inbox_index_path, notice: "Moved to Library. Processing will begin shortly."
    end
  end

  def skip
    user_episode = current_user.user_episodes.find(params[:id])
    user_episode.move_to_trash!
    redirect_to inbox_index_path, notice: "Moved to Trash"
  end

  def clear
    count = current_user.user_episodes.in_inbox.count

    if count.zero?
      redirect_to inbox_index_path, alert: "Inbox is already empty"
      return
    end

    current_user.user_episodes.in_inbox.update_all(
      location: "trash",
      trashed_at: Time.current,
      updated_at: Time.current
    )

    redirect_to inbox_index_path, notice: "Cleared #{count} episode#{'s' unless count == 1} from inbox"
  end

end
