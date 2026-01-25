Rails.application.routes.draw do
  # Podcasts: search, view, subscribe/unsubscribe
  resources :podcasts, only: [ :index, :show, :create, :destroy ]

  # User's subscribed podcasts
  resources :subscriptions, only: [ :index ]

  # Inbox: triage episodes
  resources :inbox, only: [ :index, :create ] do
    collection do
      post :add_to_library
      post :skip
    end
  end

  # Library: processed episodes
  resources :library, only: [ :index, :show ] do
    member do
      post :archive
      post :regenerate
    end
  end

  # Archive: finished episodes
  resources :archive, only: [ :index, :show ] do
    member do
      post :restore
    end
  end

  # Trash: skipped/deleted episodes
  resources :trash, only: [ :index ] do
    member do
      post :restore
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root path
  root "inbox#index"
end
