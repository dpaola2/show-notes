class Api::EpisodesController < Api::BaseController
  def library_entry
    @user_episode = current_user.user_episodes
      .includes(episode: [ :podcast, :summary ])
      .find_by!(episode_id: params[:episode_id])

    render "api/library/show"
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
