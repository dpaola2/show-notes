class SubscriptionsController < ApplicationController
  def index
    @subscriptions = current_user.subscriptions.includes(:podcast).order(created_at: :desc)
  end
end
