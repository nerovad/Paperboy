require 'sidekiq/web'

Rails.application.routes.draw do
  resources :probation_transfer_requests
  get "forms/home"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  mount Sidekiq::Web => '/sidekiq'

  root "forms#home"

  resources :parking_lot_submissions, only: [:new, :create, :index] do
    member do
      get :pdf
      patch :approve
      patch :deny
    end
  end

  # config/routes.rb
resources :billing_tools, only: [:new, :create] do
  collection do
    post :move_to_production
    post :run_monthly_billing
    post :backup_staging
    post :backup_production
  end
end

resources :creative_job_requests, only: [:new, :create]

    get "/lookups/divisions", to: "lookups#divisions"
    get "/lookups/departments", to: "lookups#departments"
    get "/lookups/units", to: "lookups#units"
end
