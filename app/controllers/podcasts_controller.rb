class PodcastsController < ApplicationController
  before_action :require_current_user
  before_action :set_podcast, only: [ :show, :destroy ]

  def index
    @podcasts = []

    if params[:q].present?
      @podcasts = search_podcasts(params[:q])
    end
  end

  def show
    @episodes = @podcast.episodes.order(published_at: :desc)
  end

  def create
    podcast_data = fetch_podcast_from_api(params[:feed_id])
    return redirect_to podcasts_path, alert: "Podcast not found" unless podcast_data

    @podcast = find_or_create_podcast(podcast_data)
    subscription = current_user.subscriptions.find_or_initialize_by(podcast: @podcast)

    if subscription.new_record?
      subscription.save!
      FetchPodcastFeedJob.perform_later(@podcast.id, initial_fetch: true)
      redirect_to subscriptions_path, notice: "Subscribed to #{@podcast.title}. Fetching episodes..."
    else
      redirect_to subscriptions_path, notice: "Already subscribed to #{@podcast.title}"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to podcasts_path, alert: "Failed to subscribe: #{e.message}"
  end

  def destroy
    subscription = current_user.subscriptions.find_by(podcast: @podcast)
    subscription&.destroy

    redirect_to subscriptions_path, notice: "Unsubscribed from #{@podcast.title}"
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:id])
  end

  def search_podcasts(query)
    client = PodcastIndexClient.new
    results = client.search(query, max: 20)

    results.map do |feed|
      {
        feed_id: feed["id"],
        title: feed["title"],
        author: feed["author"],
        description: feed["description"],
        artwork_url: feed["artwork"],
        feed_url: feed["url"],
        subscribed: subscribed_feed_ids.include?(feed["id"].to_s)
      }
    end
  rescue PodcastIndexClient::Error => e
    Rails.logger.error("Podcast Index search failed: #{e.message}")
    []
  end

  def fetch_podcast_from_api(feed_id)
    client = PodcastIndexClient.new
    client.podcast(feed_id)
  rescue PodcastIndexClient::Error => e
    Rails.logger.error("Podcast Index fetch failed: #{e.message}")
    nil
  end

  def find_or_create_podcast(api_data)
    Podcast.find_or_create_by!(guid: api_data["id"].to_s) do |podcast|
      podcast.title = api_data["title"]
      podcast.author = api_data["author"]
      podcast.description = api_data["description"]
      podcast.feed_url = api_data["url"]
      podcast.artwork_url = api_data["artwork"]
    end
  end

  def subscribed_feed_ids
    @subscribed_feed_ids ||= current_user.podcasts.pluck(:guid)
  end

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
