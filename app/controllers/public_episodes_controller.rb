class PublicEpisodesController < ApplicationController
  skip_before_action :require_authentication

  def show
    @episode = Episode.includes(:podcast, :summary).find_by(id: params[:id])

    unless @episode
      render plain: "Episode not found", status: :not_found
      return
    end

    @podcast = @episode.podcast
    @summary = @episode.summary

    log_utm_params if utm_params_present?

    render layout: "public"
  end

  def share
    episode = Episode.find_by(id: params[:id])

    unless episode
      head :not_found
      return
    end

    share_event = ShareEvent.new(
      episode: episode,
      user: current_user,
      share_target: params[:share_target],
      user_agent: request.user_agent,
      referrer: request.referer
    )

    if share_event.save
      head :created
    else
      head :unprocessable_entity
    end
  end

  private

  def log_utm_params
    Rails.logger.info(
      "[UTM Visit] episode_id=#{@episode.id} " \
      "utm_source=#{params[:utm_source]} " \
      "utm_medium=#{params[:utm_medium]} " \
      "utm_content=#{params[:utm_content]}"
    )
  end

  def utm_params_present?
    params[:utm_source].present? || params[:utm_medium].present? || params[:utm_content].present?
  end
end
