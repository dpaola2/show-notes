class ImportsController < ApplicationController
  skip_before_action :require_authentication
  before_action :authenticate_user!

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

    xml = file.read
    @feeds = OpmlParser.parse(xml)

    @result = OpmlImportService.subscribe_all(current_user, @feeds)

    @podcasts = current_user.podcasts
      .where(feed_url: @feeds.map(&:feed_url))
      .order(:title)

    render :select_favorites
  rescue OpmlParser::Error => e
    redirect_to new_import_path, alert: e.message
  end

  # POST /import/process_favorites
  def process_favorites
    podcast_ids = Array(params[:podcast_ids]).reject(&:blank?)
    if podcast_ids.empty?
      redirect_to new_import_path, alert: "Please select at least one podcast"
      return
    end

    OpmlImportService.process_favorites(current_user, podcast_ids)
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
