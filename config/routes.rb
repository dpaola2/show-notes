Rails.application.routes.draw do
  # Authentication
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  get "login/sent", to: "sessions#sent", as: :magic_link_sent
  get "auth/verify", to: "sessions#verify", as: :verify_magic_link
  delete "logout", to: "sessions#destroy", as: :logout

  # Podcasts: search, view, subscribe/unsubscribe
  resources :podcasts, only: [ :index, :show, :create, :destroy ]

  # User's subscribed podcasts
  resources :subscriptions, only: [ :index ]

  # Inbox: triage episodes
  resources :inbox, only: [ :index, :create ] do
    collection do
      post :add_to_library
      post :skip
      post :retry_processing
      delete :clear
    end
  end

  # Library: processed episodes
  resources :library, only: [ :index, :show ] do
    member do
      post :archive
      post :regenerate
      post :retry_processing
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

  # OPML Import
  resource :import, only: [ :new, :create ]
  get "import/select_favorites", to: "imports#select_favorites", as: :select_favorites_imports
  post "import/process_favorites", to: "imports#process_favorites", as: :process_favorites_imports
  get "import/complete", to: "imports#complete", as: :complete_imports

  # Episodes: subscription-scoped episode detail (for digest links)
  resources :episodes, only: [ :show ]

  # Public episode pages (no auth required)
  resources :public_episodes, only: [ :show ], path: "e"
  post "e/:id/share", to: "public_episodes#share", as: :share_episode

  # Tracking: email open/click tracking (no auth required)
  get "t/:token", to: "tracking#click", as: :tracking_click
  get "t/:token/pixel.gif", to: "tracking#pixel", as: :tracking_pixel

  # User settings
  resource :settings, only: [ :show, :update ]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root path
  root "inbox#index"
end
