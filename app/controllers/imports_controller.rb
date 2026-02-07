class ImportsController < ApplicationController
  skip_before_action :require_authentication
  before_action :authenticate_user!

  MAX_FILE_SIZE = 1.megabyte

  # GET /import/new
  def new
  end

  # POST /import
  def create
    file = params[:opml_file]
    unless file.present?
      redirect_to new_import_path, alert: "Please select a file to upload"
      return
    end

    if file.size > MAX_FILE_SIZE
      redirect_to new_import_path, alert: "File is too large (max 1MB). Please upload a smaller OPML file."
      return
    end

    xml = file.read
    feeds = OpmlParser.parse(xml)

    result = OpmlImportService.subscribe_all(current_user, feeds)

    podcast_ids = current_user.podcasts
      .where(feed_url: feeds.map(&:feed_url))
      .pluck(:id)

    session[:import_podcast_ids] = podcast_ids
    session[:import_skipped_count] = result.skipped.size
    session[:import_failed] = result.failed.map { |f| { feed_url: f[:feed].feed_url, error: f[:error] } }

    redirect_to select_favorites_imports_path
  rescue OpmlParser::Error => e
    redirect_to new_import_path, alert: e.message
  end

  # GET /import/select_favorites
  def select_favorites
    podcast_ids = session[:import_podcast_ids]
    unless podcast_ids.present?
      redirect_to new_import_path, alert: "No import in progress. Please upload an OPML file."
      return
    end

    @podcasts = current_user.podcasts.where(id: podcast_ids).order(:title)
    @skipped_count = session[:import_skipped_count] || 0
    @failed = session[:import_failed] || []
  end

  # POST /import/process_favorites
  def process_favorites
    podcast_ids = Array(params[:podcast_ids]).reject(&:blank?)
    if podcast_ids.empty?
      redirect_to new_import_path, alert: "Please select at least one podcast"
      return
    end

    OpmlImportService.process_favorites(current_user, podcast_ids)
    session.delete(:import_podcast_ids)
    session.delete(:import_skipped_count)
    session.delete(:import_failed)
    redirect_to complete_imports_path
  end

  # GET /import/complete
  def complete
  end

  private

  def authenticate_user!
    redirect_to root_path unless current_user
  end
end
