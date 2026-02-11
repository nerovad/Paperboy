require 'sidekiq/web'

Rails.application.routes.draw do
  resources :workplace_violence_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :osha301_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :leave_of_absence_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :rm75_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  # ============================================================================
  # PWA
  # ============================================================================
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :work_schedule_or_location_update_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :social_media_forms
  resources :gym_locker_forms
  resources :carpool_forms
  resources :brown_mail_forms
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

  resources :acl, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do
      post :add_member
      delete :remove_member
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
  get "/status/status_options", to: "status#status_options", as: :status_status_options
  resources :saved_searches, only: [:create, :destroy]

  # Task Reassignment Routes
  resources :task_reassignments, only: [] do
    collection do
      post :reassign
      post :take_back
      get :history
    end
  end

  # ============================================================================
  # Dashboards
  # ============================================================================
  get "/dashboards", to: "dashboards#index", as: :dashboards
  post "/dashboards/embed_token", to: "dashboards#embed_token", as: :dashboard_embed_token

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

  resources :critical_information_reportings, only: [:new, :create, :show, :edit, :update] do
    member do
      get :pdf
      get :download_media
      patch :approve
      patch :deny
      patch :update_status
    end
  end

  # ============================================================================
  # Standard Forms (alphabetical)
  # ============================================================================
  resources :creative_job_requests, only: [:new, :create]

  # ============================================================================
  # Lookups & Dynamic Data
  # ============================================================================
  get "/lookups/agencies", to: "lookups#agencies"
  get "/lookups/divisions", to: "lookups#divisions"
  get "/lookups/departments", to: "lookups#departments"
  get "/lookups/units", to: "lookups#units"

  # NHTSA vehicle lookup proxy (CSP blocks direct browser fetch)
  get "/api/nhtsa/makes", to: "api/nhtsa#makes"
  get "/api/nhtsa/models", to: "api/nhtsa#models"

  # ============================================================================
  # Invoicing & Billing
  # ============================================================================
  get "/invoice", to: "invoices#show"
  get "/invoice", to: "invoices#new"

  # ============================================================================
  # Debug & Development Tools
  # ============================================================================
  get "/debug/invoice_grid", to: "grid#show"

  # MatthewTestReport report
  get  "/reports/matthew_test_report",     to: "matthew_test_report_reports#show", as: "matthew_test_report_reports"
  post "/reports/matthew_test_report/run", to: "matthew_test_report_reports#run",  as: "matthew_test_report_reports_run"

# MatthewTestYay report
get  "/reports/matthew_test_yay",     to: "matthew_test_yay_reports#show", as: "matthew_test_yay_reports"
post "/reports/matthew_test_yay/run", to: "matthew_test_yay_reports#run",  as: "matthew_test_yay_reports_run"
end
