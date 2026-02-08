class EpisodesController < ApplicationController
  def show
    @episode = Episode.find(params[:id])

    unless current_user.podcasts.exists?(id: @episode.podcast_id)
      redirect_to root_path, alert: "Episode not found"
      return
    end

    @podcast = @episode.podcast
    @summary = @episode.summary
  end
end
