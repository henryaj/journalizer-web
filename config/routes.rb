Rails.application.routes.draw do
  # Web authentication (session-based)
  resource :session
  resource :registration, only: [:new, :create]
  resources :passwords, param: :token

  # OAuth callbacks
  get "/auth/:provider/callback", to: "omniauth_callbacks#google_oauth2", as: :omniauth_callback
  get "/auth/failure", to: "omniauth_callbacks#failure"

  # Web dashboard
  resource :camera, only: [:show]
  resources :uploads, only: [:new, :create]
  resources :api_tokens, only: [:index, :create, :destroy]
  resources :entries, only: [] do
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
