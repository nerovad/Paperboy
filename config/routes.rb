require 'sidekiq/web'

Rails.application.routes.draw do
  get "forms/home"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  mount Sidekiq::Web => '/sidekiq'

  root "forms#home"

  resources :parking_lot_submissions, only: [:new, :create, :index, :show] do
    member do
      get :pdf
      patch :approve
      patch :deny
    end
  end

  resources :probation_transfer_requests, only: [:new, :create, :index, :show] do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :withdraw
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

resources :rm75_forms, only: [:new, :create]

resources :rm75i_forms, only: [:new, :create]

resources :loa_forms, only: [:new, :create]

    get "/lookups/divisions", to: "lookups#divisions"
    get "/lookups/departments", to: "lookups#departments"
    get "/lookups/units", to: "lookups#units"

    get "/form_success", to: "shared#form_success", as: :form_success

    get "/inboxqueue", to: "inbox#queue", as: "inbox_queue"

    get "/status", to: "status#index", as: :status

end
