require "sidekiq/web"

Rails.application.routes.draw do
  resources :fleet_vehicle_garaging_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :form_request_forms do
    member do
            get :download_attach_existing_pdf_form
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :id_badge_request_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :bike_locker_forms do
    collection do
      get :available_lockers
    end
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :pcard_request_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :notice_of_change_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :workplace_violence_forms do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :osha_reports do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  get "osha_log", to: "osha_logs#index", as: :osha_log
  get   "osha_300a",         to: "osha_300as#show",    as: :osha_300a
  patch "osha_300a",         to: "osha_300as#update"
  get   "osha_300a/payload", to: "osha_300as#payload", as: :osha_300a_payload
  post  "osha_300a/submit",  to: "osha_300as#submit",  as: :osha_300a_submit
  resources :leave_of_absence_forms do
    member do
            get :download_doctors_note_attachment
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :safety_reports do
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
  # ============================================================================
  # Root & Home
  # ============================================================================
  root "forms#home"
  get "forms/home"
  get "/form_success", to: "shared#form_success", as: :form_success
  get "/ticket_success", to: "shared#ticket_success", as: :ticket_success

  # ============================================================================
  # Authentication & Sessions
  # ============================================================================
  # OAuth/Entra ID routes
  get "/auth/callback", to: "sessions#create_oauth"
  get "/auth/failure", to: "sessions#failure"
  post "/auth/entra_id", to: "sessions#setup", as: :auth_setup

  # Legacy login (keep for admin impersonation)
  post "/login", to: "sessions#create_legacy"
  delete "/logout", to: "sessions#destroy"

  # Contractor (non-Active-Directory) password login + set/reset password
  get    "/contractor/login",  to: "contractor_sessions#new",     as: :contractor_login
  post   "/contractor/login",  to: "contractor_sessions#create"
  delete "/contractor/logout", to: "contractor_sessions#destroy", as: :contractor_logout

  get   "/contractor/password/new",  to: "contractor_passwords#new",    as: :new_contractor_password
  post  "/contractor/password",      to: "contractor_passwords#create", as: :contractor_password
  get   "/contractor/password/edit", to: "contractor_passwords#edit",   as: :edit_contractor_password
  patch "/contractor/password",      to: "contractor_passwords#update"

  # ============================================================================
  # Admin & Tools
  # ============================================================================
  namespace :admin do
    resources :impersonations, only: [ :new, :create, :destroy ]
    resources :data_validation, only: [ :index ]
  end

  resources :pcard_inventory, only: [ :index, :new, :create, :edit, :update ] do
    collection do
      get :export
    end
  end

  resources :authorization_console, only: [ :index, :new, :create ] do
    collection do
      delete :destroy_all_for_employee
      get    :group_edit
      patch  :group_update
      delete :group_destroy
    end
  end

  resources :acl, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    member do
      post :add_member
      delete :remove_member
      get :permissions
      patch :update_permissions
      post  :add_contractor
      get   :edit_contractor
      patch :update_contractor
      patch :toggle_contractor
      post  :resend_contractor_welcome
    end
    collection do
      get :org_permissions
      patch :update_org_permissions
    end
  end

  resources :billing_tools, only: [ :new, :create ] do
    collection do
      post :move_to_production
      post :run_monthly_billing
      post :backup_staging
      post :backup_production
    end
  end

  mount Sidekiq::Web => "/sidekiq"

  # ============================================================================
  # Reports & Scheduled Reports
  # ============================================================================
  get "reports", to: "reports#index", as: "reports"
  post "reports/generate", to: "reports#generate", as: "reports_generate"
  get "reports/status_options", to: "reports#status_options", as: "reports_status_options"

  resources :scheduled_reports do
    member do
      patch :toggle
    end
  end

  # ============================================================================
  # Inbox & Submissions
  # ============================================================================
  get "/inboxqueue", to: "inbox#queue", as: "inbox_queue"
  get "/inbox/status_history/:type/:id", to: "inbox#status_history", as: "inbox_status_history"
  get "/submissions", to: "submissions#index", as: :submissions
  get "/submissions/status_options", to: "submissions#status_options", as: :submissions_status_options
  resources :saved_searches, only: [ :create, :destroy ]

  # Per-user column/filter layout for the Inbox & Submissions tables
  patch "/settings/table_layout", to: "settings#table_layout", as: :settings_table_layout

  resources :form_submission_copies, only: [] do
    member do
      delete :dismiss
    end
  end

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

  # ============================================================================
  # Form Templates & Builder
  # ============================================================================
  resources :form_templates do
    member do
      patch :archive
      patch :unarchive
    end
  end

  resources :form_visibility_grants, only: [ :index, :create, :destroy ]

  # ============================================================================
  # Workflow Forms (with approval/denial workflows)
  # ============================================================================
  resources :parking_lot_submissions, only: [ :new, :create, :index, :show ] do
    member do
      get :pdf
      patch :approve
      patch :deny
    end
  end

  resources :probation_transfer_requests, only: [ :new, :create, :index, :show ] do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :withdraw
    end
  end

  resources :critical_information_reportings, only: [ :new, :create, :show, :edit, :update ] do
    member do
      get :pdf
      get "download_media/:attachment_id", action: :download_media, as: :download_media
      patch :approve
      patch :deny
      patch :update_status
      patch :reopen
    end
  end

  # ============================================================================
  # Standard Forms (alphabetical)
  # ============================================================================
  resources :creative_job_requests, only: [ :new, :create ]
  get "help", to: "help#index", as: :help
  resource :settings, only: [ :show, :update ]
  resources :help_tickets, only: [ :new, :create, :index, :show ] do
    member do
      patch :close
    end
  end

  # ============================================================================
  # Lookup Tables Management
  # ============================================================================
  resources :lookup_tables, only: [ :index, :show, :new, :create ]

  # ============================================================================
  # Lookups & Dynamic Data
  # ============================================================================
  get "/lookups/agencies", to: "lookups#agencies"
  get "/lookups/divisions", to: "lookups#divisions"
  get "/lookups/departments", to: "lookups#departments"
  get "/lookups/units", to: "lookups#units"
  get "/lookups/supervisors", to: "lookups#supervisors"
  get "/lookups/employees", to: "lookups#employees"
  get "/lookups/answer_fill", to: "lookups#answer_fill"
  get "/lookups/categories", to: "lookups#categories"
  get "/lookups/tables", to: "lookups#tables"
  get "/lookups/columns", to: "lookups#columns"
  get "/lookups/category_values", to: "lookups#category_values"

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
