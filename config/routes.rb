require 'sidekiq/web'

Rails.application.routes.draw do
  resources :arizona_cardinals_forms
  # ============================================================================
  # Root & Home
  # ============================================================================
  root "forms#home"
  get "forms/home"
  get "/form_success", to: "shared#form_success", as: :form_success

  # ============================================================================
  # Authentication & Sessions
  # ============================================================================
  # OAuth/Entra ID routes
  get '/auth/callback', to: 'sessions#create_oauth'
  get '/auth/failure', to: 'sessions#failure'
  post '/auth/entra_id', to: 'sessions#setup', as: :auth_setup

  # Legacy login (keep for admin impersonation)
  post "/login", to: "sessions#create_legacy"
  delete "/logout", to: "sessions#destroy"

  # ============================================================================
  # Admin & Tools
  # ============================================================================
  namespace :admin do
    resources :impersonations, only: [:new, :create, :destroy]
  end

  resources :authorization_console, only: [:index, :new, :create, :edit, :update, :destroy] do
    collection do
      delete :destroy_all_for_employee
    end
  end

  resources :billing_tools, only: [:new, :create] do
    collection do
      post :move_to_production
      post :run_monthly_billing
      post :backup_staging
      post :backup_production
    end
  end

  mount Sidekiq::Web => '/sidekiq'

  # ============================================================================
  # Reports & Scheduled Reports
  # ============================================================================
  get 'reports', to: 'reports#index', as: 'reports'
  post 'reports/generate', to: 'reports#generate', as: 'reports_generate'
  get 'reports/status_options', to: 'reports#status_options', as: 'reports_status_options'

  resources :scheduled_reports do
    member do
      patch :toggle
    end
  end

  # ============================================================================
  # Inbox & Status
  # ============================================================================
  get "/inboxqueue", to: "inbox#queue", as: "inbox_queue"
  get "/status", to: "status#index", as: :status

  # ============================================================================
  # Form Templates & Builder
  # ============================================================================
  resources :form_templates

  # ============================================================================
  # Workflow Forms (with approval/denial workflows)
  # ============================================================================
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

  # ============================================================================
  # Standard Forms (alphabetical)
  # ============================================================================
  resources :bike_locker_permits
  resources :buffalo_bills_forms
  resources :carpool_forms
  resources :chicago_bears_forms
  resources :chicago_blackhawks_forms
  resources :creative_job_requests, only: [:new, :create]
  resources :critical_information_reportings
  resources :dallas_cowboys_forms
  resources :detroit_lions_forms
  resources :jungle_book_forms
  resources :la_chargers_forms
  resources :la_rams_forms
  resources :loa_forms, only: [:new, :create]
  resources :minnesota_vikings_forms
  resources :new_england_patriots_forms
  resources :new_orleans_saints_forms
  resources :polar_express_forms
  resources :princess_bride_forms
  resources :rm75_forms, only: [:new, :create]
  resources :rm75i_forms, only: [:new, :create]
  resources :seattle_seahawks_forms
  resources :sonic_the_hedgehog_forms
  resources :super_mario_forms

  # ============================================================================
  # Lookups & Dynamic Data
  # ============================================================================
  get "/lookups/divisions", to: "lookups#divisions"
  get "/lookups/departments", to: "lookups#departments"
  get "/lookups/units", to: "lookups#units"

  # ============================================================================
  # Invoicing & Billing
  # ============================================================================
  get "/invoice", to: "invoices#show"
  get "/invoice", to: "invoices#new"

  # ============================================================================
  # Debug & Development Tools
  # ============================================================================
  get "/debug/invoice_grid", to: "grid#show"
end
