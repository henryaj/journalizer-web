Rails.application.routes.draw do
  # Web authentication (session-based)
  resource :session
  post "session/dev_login", to: "sessions#dev_login", as: :dev_login if Rails.env.development?
  resource :registration, only: [:new, :create]
  resources :passwords, param: :token

  # OAuth callbacks
  get "/auth/:provider/callback", to: "omniauth_callbacks#google_oauth2", as: :omniauth_callback
  get "/auth/failure", to: "omniauth_callbacks#failure"

  # Feedback
  resource :feedback, only: [:create], controller: "feedback"

  # Stripe webhooks (at root level for Stripe dashboard config)
  post "stripe/webhooks", to: "api/v1/webhooks#stripe"

  # Web dashboard
  resource :camera, only: [:show]
  resources :uploads, only: [:new, :create]
  resources :transcription_jobs, only: [:destroy] do
    member do
      get :review
      patch :confirm
      post :process_partial
    end
    resources :job_pages, only: [] do
      member do
        post :rotate
      end
    end
  end
  resources :api_tokens, only: [:index, :create, :destroy]
  resource :account, only: [:show, :update], controller: "account"
  resources :entries, only: [:index, :destroy] do
    member do
      get :download
    end
  end
  resource :export, only: [:create]
  resources :payments, only: [:new, :create] do
    collection do
      get :success
      get :cancel
    end
  end

  # API routes (token-based auth)
  namespace :api do
    namespace :v1 do
      # User info
      get :me, to: "users#me"

      # Journal entries (for Obsidian plugin)
      resources :entries, only: [:index, :show] do
        member do
          get :markdown
          get "images/:index", action: :image, as: :image
          post :mark_synced
        end
      end

      # Transcription jobs
      resources :transcriptions, only: [:create, :show]

      # Stripe webhooks (no auth)
      post :webhooks, to: "webhooks#stripe"
    end
  end

  # Dashboard
  get "dashboard", to: "dashboard#show"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path - show landing for visitors, redirect to dashboard for logged in users
  root "home#index"
end
