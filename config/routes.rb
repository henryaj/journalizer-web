Rails.application.routes.draw do
  # Web authentication (session-based)
  resource :session
  resource :registration, only: [:new, :create]
  resources :passwords, param: :token

  # Web dashboard
  resources :api_tokens, only: [:index, :create, :destroy]
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

  # Root path - redirect to dashboard if logged in, otherwise show landing
  root "dashboard#show"
end
