# frozen_string_literal: true

Rails.application.routes.draw do
  resources :textbook_and_tuition_reimbursement_forms, controller: 'forms/textbook_and_tuition_reimbursement_forms' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :telework_log_forms, controller: 'forms/telework_log_forms' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  namespace :digital_asset_management do
    root 'dashboard#home'
    get 'dashboard', to: 'dashboard#index', as: :dashboard

    # The sidebar search box and the Advanced Search modal both GET here; the
    # difference between them is only how many filter params they send.
    resources :assets do
      member do
        post :share
        # A referenced asset's original is on a share, not on a service, so it
        # cannot be a blob URL. See AssetsController#original.
        get :original
      end
    end

    # The action bar above the library. Its own path rather than a collection
    # route on assets, where POST assets/bulk/share would read as sharing the
    # asset with id "bulk". See BulkAssetsController.
    resource :bulk_assets, only: [] do
      post :publish
      post :share
      post :metadata
      post :add_to_collection
      post :archive
    end

    resources :collections do
      # Adding is a collection route so the picker on an asset page can choose
      # which collection to drop it into from a select rather than a URL.
      collection do
        post :add_asset
      end
      member do
        delete :remove_asset
      end
    end

    resources :jobs, only: %i[index show] do
      member do
        post :retry
        post :cancel
      end
    end

    resources :workflows do
      member do
        post :run
        patch :toggle
      end
    end

    resources :shares, only: %i[index show destroy] do
      member do
        post :revoke
      end
    end

    # Personal, not administrative — one per signed-in user, so a singular
    # resource with no id. The Storage screen is where it is set.
    resource :upload_destination, only: %i[update]

    resources :storage_locations do
      member do
        post :make_default
        post :move_assets
        patch :toggle
        # Forgets what failed to ingest, so the next scan tries those files
        # again — after whatever was wrong with them has been put right.
        post :retry_failures
        # Queues the previews for everything here that has none.
        post :rebuild_derivatives
      end
    end

    # Where the library can send a finished asset, and what was sent.
    resources :publish_targets do
      member do
        patch :toggle
        # Starts the OAuth round trip; the callback below finishes it.
        post :connect, to: 'publish_connections#create'
        delete :disconnect
      end
    end

    # One callback for every provider, because each has to be registered by
    # hand against the application. Which target is being connected rides in
    # the state parameter. GET because that is how a browser comes back.
    get 'publish_connections/callback', to: 'publish_connections#callback'

    resources :publications, only: %i[index show create] do
      member do
        post :retry
        post :cancel
      end
    end

    # One endpoint for both stars, since the button is a toggle and the subject
    # may be an asset or a collection.
    post 'favorites', to: 'favorites#toggle', as: :favorites

    # Every image, video and stored download in the DAM, through a signed
    # token rather than a standing Active Storage URL. See FilesController.
    get 'files/:token', to: 'files#show', as: :file
  end

  # Outside the namespace and outside the sign-in, because the fetcher is
  # Instagram rather than a person. See DamMediaController: the token is good
  # only while the publish that minted it is in flight.
  get 'dam/media/:token', to: 'dam_media#show', as: :dam_public_media

  namespace :aim do
    root 'dashboard#home'
    get 'dashboard', to: 'dashboard#index', as: :dashboard

    resources :invoices, only: %i[index show update], constraints: { id: %r{[^/]+} } do
      collection do
        patch :reassign_many
      end
      member do
        get :pdf
        patch :reassign
        patch :lock
        post :unlock
        post :claim
        post :restore
        post :relookup
      end
    end
    get 'my_queue', to: 'my_queue#index', as: :my_queue
    get 'shared_queues', to: 'shared_queues#index', as: :shared_queues
    get 'budget_units', to: 'budget_units#index', as: :budget_units
    get 'people', to: 'people#index', as: :people
    get 'counts', to: 'counts#show', as: :counts
    patch 'mode', to: 'modes#update', as: :mode
    get 'admin', to: 'admin#index', as: :admin
    get 'admin/employees', to: 'members#employees', as: :admin_employees
    get 'admin/budget_units', to: 'enabled_units#index', as: :enabled_units
    patch 'admin/budget_units', to: 'enabled_units#update'
    resources :members, only: %i[create show destroy], path: 'admin/users' do
      member do
        patch :deactivate, to: 'member_statuses#deactivate'
        patch :reactivate, to: 'member_statuses#reactivate'
        patch :fiscal, to: 'member_fiscal#update'
      end
      resources :budget_units, only: %i[create update destroy], controller: 'member_budget_units'
    end
    resources :uploads, only: %i[new create]
    get 'fiscal', to: 'fiscal#index', as: :fiscal
    post 'fiscal/export', to: 'fiscal_exports#create', as: :fiscal_export
    resources :fiscal_invoices, path: 'fiscal', controller: 'fiscal', only: %i[show update],
                                constraints: { id: %r{[^/]+} } do
      get :pdf, on: :member
    end
    resources :coding_imports, only: %i[index new create show destroy], path: 'lookups/imports' do
      get :template, on: :collection
      member do
        post :apply
        post :undo
      end
    end
    resources :coding_rules, only: %i[index show update], path: 'lookups', constraints: { id: /\d+/ } do
      patch :retire, on: :member
    end
    resources :vendor_aliases, only: %i[index create update destroy]
    resources :vendor_rules, only: %i[index create update destroy]
  end

  namespace :production do
    root 'dashboard#index'
  end

  namespace :billing do
    root 'dashboard#index'

    resource :dashboard, only: :show, controller: :dashboards
    resource :customer_lookup, only: %i[show create], controller: :customer_lookups
    resource :audit, only: :show, controller: :audits
    get 'audit/cost/:key/rows', to: 'audits#cost_rows', as: :cost_audit_rows
    get 'audit/type/:code/rows', to: 'audits#type_rows', as: :type_audit_rows
    get 'audit/:key/rows', to: 'audits#rows', as: :audit_rows
    get 'audit/:key', to: 'audits#detail', as: :audit_detail
    resource :reporting_period, only: %i[show update]
    resource :data_refresh, only: %i[show update] do
      post :restart
    end
    get 'data_refresh/runs/:run_id', to: 'data_refreshes#progress', as: :data_refresh_run
    get 'data_refresh/runs/:run_id/status', to: 'data_refreshes#status', as: :data_refresh_run_status
    get 'data_refresh/runs/:run_id/log', to: 'data_refreshes#log', as: :data_refresh_run_log
    resources :email_recipients, only: %i[index create destroy]
    resource :email_subjects, only: %i[show update]
    resource :email_reports, only: %i[show create]
    resource :archive_reports, only: %i[show create]
    get 'enable', to: 'billing_types#index', as: :billing_types
    patch 'enable', to: 'billing_types#update'
    get 'monthly_reports/:operation', to: 'monthly_reports#show', as: :monthly_report
    post 'monthly_reports/:operation', to: 'monthly_reports#create', as: :process_monthly_report
    resources :reports, only: %i[index show], param: :filename, format: false,
                        constraints: { filename: %r{[^/]+} }

    # POST-only endpoints for Billing database maintenance actions.
    resources :tools, only: [] do
      collection do
        post :move_to_production
      end
    end
  end

  namespace :admin_tools do
    root 'dashboard#index'
  end

  namespace :p2m do
    root 'dashboard#home'
    get 'dashboard', to: 'dashboard#index', as: :dashboard
    resource :pre_production, only: :show do
      get :details
      post :send_to_printer
      delete :remove_from_printer
      delete :destroy_oms
    end
    resource :production, only: :show do
      get :preview
    end
    resource :data_reset, only: %i[show create]
    resource :quality_control, only: :show do
      get :details
    end
    resource :stage_data, only: %i[show create] do
      get :details
      get :preview
      get :print_tray_labels
      post :move_to_staging
      delete :remove_from_staging
      post :move_to_shipping_station
      delete :remove_from_shipping_station
    end
    post 'search/cancel', to: 'searches#cancel', as: :search_cancel
    get 'oms_status', to: 'oms_uploads#index', as: :oms_status
    resource :data_refresh, only: %i[show update] do
      post :restart
    end
    get 'data_refresh/runs/:run_id', to: 'data_refreshes#progress', as: :data_refresh_run
    get 'data_refresh/runs/:run_id/status', to: 'data_refreshes#status', as: :data_refresh_run_status
    get 'data_refresh/runs/:run_id/log', to: 'data_refreshes#log', as: :data_refresh_run_log
  end

  namespace :hsa_adoption_cards do
    root 'dashboard#home'
    get 'search', to: 'search#index', as: :search
    post 'search', to: 'search#create'
    get 'browse', to: 'browse#index', as: :browse
    post 'browse', to: 'browse#create'
    post 'browse/linked', to: 'browse#linked', as: :browse_linked
    get 'cards/pdf', to: 'cards#pdf', as: :card_pdf
    get 'maintenance', to: 'maintenance#index', as: :maintenance
    post 'maintenance/rebuild', to: 'maintenance#rebuild', as: :maintenance_rebuild
  end

  namespace :itp do
    root 'dashboard#home'
    get 'dashboard', to: 'dashboard#index', as: :dashboard
  end

  namespace :data_runner do
    root 'dsls#index'

    resources :logs
    resource :inbox_dsls, only: :create
    resource :database_dsls, only: %i[new create] do
      get :databases
      get :tables
    end
    resources :dsls, only: %i[index show new create edit update destroy], param: :name do
      member do
        post :run
        get 'reference', to: 'dsl_references#show', as: :reference
        get :outputs
        get 'outputs/backup', to: 'backup_outputs#index', as: :backup_outputs
        delete 'outputs/backup', to: 'backup_outputs#destroy_all', as: :destroy_backup_outputs
        delete 'outputs/backup/*path', to: 'backup_outputs#destroy', as: :destroy_backup_output, format: false
        get 'outputs/*path', action: :output, as: :output, format: false
      end
    end
    get '/dsl_groups/new', to: 'dsls#new_group', as: :new_dsl_group
    post '/dsl_groups', to: 'dsls#create_group', as: :dsl_groups
    patch '/dsl_groups/:group', to: 'dsls#update_group', as: :dsl_group
    patch '/dsl_groups/:group/rename', to: 'dsls#rename_group', as: :rename_dsl_group
    delete '/dsl_groups/:group', to: 'dsls#destroy_group', as: :destroy_dsl_group
    post '/dsl_groups/:group/refresh', to: 'group_refreshes#create', as: :refresh_dsl_group
    get '/group_refreshes', to: 'group_refreshes#index', as: :group_refreshes
    get '/runs/:id', to: 'runs#show', as: :run
    resources :group_runs, only: :show do
      member { get :status }
    end
  end

  resources :fleet_vehicle_garaging_forms, controller: 'forms/fleet_vehicle_garaging_forms' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :form_request_forms, controller: 'forms/form_request_forms' do
    member do
      get :download_attach_existing_pdf_form
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :id_badge_request_forms, controller: 'forms/id_badge_request_forms' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :bike_locker_forms, controller: 'forms/bike_locker_forms' do
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
  resources :pcard_request_forms, controller: 'forms/pcard_request_forms' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :notice_of_change_forms, controller: 'forms/notice_of_change_forms' do
    collection do
      get :accounting_options
    end
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :workplace_violence_forms, controller: 'forms/workplace_violence_forms' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :osha_reports, controller: 'forms/osha_reports' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  get   'osha_300a',         to: 'osha_300as#show', as: :osha_300a
  patch 'osha_300a',         to: 'osha_300as#update'
  get   'osha_300a/payload', to: 'osha_300as#payload', as: :osha_300a_payload
  post  'osha_300a/submit',  to: 'osha_300as#submit',  as: :osha_300a_submit
  resources :leave_of_absence_forms, controller: 'forms/leave_of_absence_forms' do
    member do
      get :download_doctors_note_attachment
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :safety_reports, controller: 'forms/safety_reports' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :sheriff_safety_reporting_forms, controller: 'forms/sheriff_safety_reporting_forms' do
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
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker

  resources :work_schedule_or_location_update_forms,
            controller: 'forms/work_schedule_or_location_update_forms' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :update_status
    end
  end
  resources :social_media_forms, controller: 'forms/social_media_forms'
  resources :gym_locker_forms, controller: 'forms/gym_locker_forms'
  resources :carpool_forms, controller: 'forms/carpool_forms'
  # ============================================================================
  # Root & Home
  # ============================================================================
  root 'forms#home'
  # Both fill a frame in a dialog the layout renders; neither is a page anyone
  # navigates to on its own.
  get '/who_am_i', to: 'who_am_i#show', as: :who_am_i
  get '/command_palette', to: 'command_palette#show', as: :command_palette
  get 'forms/home'
  get '/form_success', to: 'shared#form_success', as: :form_success
  get '/ticket_success', to: 'shared#ticket_success', as: :ticket_success

  # ============================================================================
  # Authentication & Sessions
  # ============================================================================
  # OAuth/Entra ID routes
  get '/auth/callback', to: 'sessions#create_oauth'
  get '/auth/failure', to: 'sessions#failure'
  post '/auth/entra_id', to: 'sessions#setup', as: :auth_setup

  # Legacy login (keep for admin impersonation)
  post '/login', to: 'sessions#create_legacy'
  delete '/logout', to: 'sessions#destroy'

  # Contractor (non-Active-Directory) password login + set/reset password
  get    '/contractor/login',  to: 'contractor_sessions#new', as: :contractor_login
  post   '/contractor/login',  to: 'contractor_sessions#create'
  delete '/contractor/logout', to: 'contractor_sessions#destroy', as: :contractor_logout

  get   '/contractor/password/new',  to: 'contractor_passwords#new',    as: :new_contractor_password
  post  '/contractor/password',      to: 'contractor_passwords#create', as: :contractor_password
  get   '/contractor/password/edit', to: 'contractor_passwords#edit',   as: :edit_contractor_password
  patch '/contractor/password',      to: 'contractor_passwords#update'

  # ============================================================================
  # Admin & Tools
  # ============================================================================
  namespace :admin do
    resources :impersonations, only: %i[new create destroy]
  end

  # Records pillar landing page (lists the Registry grid tables) + generic grid
  # + inline cell-edit endpoint.
  get '/records', to: 'records#index', as: :records
  get '/records/:slug', to: 'records_table#show', as: :records_table
  patch '/records/:slug', to: 'records_table#bulk_update'
  # Scheduled CSV exports of a grid view, managed from the grid's Export modal.
  scope '/records/:slug', as: :records_table do
    # Change history: the whole table's log, and one row's fragment for the
    # grid's History modal. Both need the table's edit grant.
    get 'changes', to: 'records_histories#index', as: :changes
    get 'rows/:id/history', to: 'records_histories#row', as: :row_history
    resources :export_schedules, only: %i[create destroy], controller: 'record_export_schedules' do
      patch :toggle, on: :member
    end
    # Conditional row colouring, managed from the grid's Highlights dialog.
    resources :highlight_rules, only: %i[create destroy], controller: 'records_highlight_rules' do
      patch :move, on: :member
    end
  end

  resources :pcard_inventory, only: %i[index new create edit update] do
    collection do
      get :export
    end
  end

  resources :authorization_console, only: %i[index new create] do
    collection do
      get    :select
      get    :group_edit
      patch  :group_update
      delete :group_destroy
    end
  end

  # Safety Reporting authorization console (HCA safety officers by org node).
  resources :safety_authorizations, only: %i[index new create edit update destroy],
                                    path: 'authorization_console/safety'

  # Critical Information Reporting authorization console (incident managers by
  # the site named in the report's "Where: Location" field).
  resources :critical_information_authorizations,
            only: %i[index new create edit update destroy],
            path: 'authorization_console/critical_information'

  # The site catalogue the CIR form's location dropdown is built from. Add and
  # delete only — a rename would orphan every report filed under the old name.
  resources :critical_information_locations,
            only: %i[new create destroy],
            path: 'authorization_console/critical_information/locations'

  # ACL > DAM Access Rules. Listed under acl/ in the address bar because
  # that is where they are managed, but a resource of their own.
  resources :dam_access_rules, path: 'acl/dam_access_rules', except: :show do
    resources :grantees, controller: 'dam_access_rule_grantees', only: %i[create destroy]
  end

  resources :acl, only: %i[index show new create edit update destroy] do
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
      get :organization_permissions
      get :org_permissions
      patch :update_org_permissions
    end
  end

  # ============================================================================
  # Reports & Scheduled Reports
  # ============================================================================
  get 'reports', to: 'reports#index', as: 'reports'
  post 'reports/generate', to: 'reports#generate', as: 'reports_generate'
  get 'reports/status_options', to: 'reports#status_options', as: 'reports_status_options'
  post 'reports/audit_export', to: 'reports#export_audit', as: 'reports_audit_export'

  resources :scheduled_reports do
    member do
      patch :toggle
    end
  end

  # ============================================================================
  # Inbox & Submissions
  # ============================================================================
  get '/inboxqueue', to: 'inbox#queue', as: 'inbox_queue'
  # Fragments the inbox history modal fetches. Kept on the /inbox path they have
  # always been served from; see SubmissionHistoriesController.
  get '/inbox/status_history/:type/:id', to: 'submission_histories#status', as: 'inbox_status_history'
  get '/inbox/edit_history/:type/:id', to: 'submission_histories#edits', as: 'inbox_edit_history'
  # A submission's comment thread, addressed the same way; see
  # SubmissionCommentsController. Deleting and downloading go by comment id.
  get '/inbox/comments/:type/:id', to: 'submission_comments#index', as: 'inbox_comments'
  post '/inbox/comments/:type/:id', to: 'submission_comments#create'
  delete '/submission_comments/:id', to: 'submission_comments#destroy', as: 'submission_comment'
  get '/submission_comments/:id/attachments/:attachment_id', to: 'submission_comments#attachment',
                                                             as: 'submission_comment_attachment'
  get '/submissions', to: 'submissions#index', as: :submissions
  get '/submissions/status_options', to: 'submissions#status_options', as: :submissions_status_options
  # Reference number typed into the quick search ("PLS-845") -> that submission.
  get '/submissions/lookup', to: 'submissions#lookup', as: :submission_lookup
  # Status change from a submission's own page, for forms that carry a status
  # dropdown in the inbox but have reached an end state and dropped out of it.
  patch '/submissions/:type/:id/status', to: 'submissions#update_status', as: :submission_status
  resources :saved_searches, only: %i[create destroy]

  # Per-user column/filter layout for the Inbox & Submissions tables
  patch '/settings/table_layout', to: 'settings#table_layout', as: :settings_table_layout

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
  get '/dashboards', to: 'dashboards#index', as: :dashboards

  # ============================================================================
  # Form Templates & Builder
  # ============================================================================
  resources :form_templates do
    member do
      patch :archive
      patch :unarchive
      get :duplicate, action: :duplicate_preview, as: :duplicate_preview
      post :duplicate
    end
  end

  # Rows behind the ACL group page's Submission Visibility section.
  resources :form_visibility_grants, only: %i[create destroy]
  resources :form_subscriptions, only: %i[create destroy] do
    # A member stepping out of (and back into) one group subscription's mail.
    resource :opt_out, only: %i[create destroy], controller: 'form_subscription_opt_outs'
  end
  resources :away_periods, only: %i[create destroy]

  # ============================================================================
  # Workflow Forms (with approval/denial workflows)
  # ============================================================================
  resources :parking_lot_submissions, only: %i[new create index show],
                                      controller: 'forms/parking_lot_submissions' do
    member do
      get :pdf
      patch :approve
      patch :deny
    end
  end

  resources :probation_transfer_requests, only: %i[new create index show edit update destroy],
                                          controller: 'forms/probation_transfer_requests' do
    member do
      get :pdf
      patch :approve
      patch :deny
      patch :withdraw
    end
  end

  resources :critical_information_reportings, only: %i[new create show edit update],
                                              controller: 'forms/critical_information_reportings' do
    member do
      get :pdf
      get 'download_media/:attachment_id', action: :download_media, as: :download_media
      patch :approve
      patch :deny
      patch :update_status
    end
  end

  # ============================================================================
  # Standard Forms (alphabetical)
  # ============================================================================
  resources :creative_job_requests, only: %i[new create], controller: 'forms/creative_job_requests'
  get 'help', to: 'help#index', as: :help
  resource :settings, only: %i[show update]
  resources :help_tickets, only: %i[new create index show] do
    member do
      patch :close
    end
  end

  namespace :coa do
    root to: 'list#home'
    get 'list', to: 'list#index'

    resource :billing_lookup, only: :show do
      get :divisions
      get :departments
      get :units
      get :objects
      get :activities
      get :cfunctions
      get :programs
      get :phases
      get :tasks
    end

    resource :customer_lookup, only: :show do
      get :employees
      get :hierarchy
      get :account_items
    end

    resources :agencies
    resources :activities
    resources :departments
    resources :divisions
    resources :functions
    resources :funds
    resources :major_programs
    resources :objects
    resources :phases
    resources :programs
    resources :revenue_sources
    resources :object_inferences
    resources :sub_units
    resources :tasks
    resources :units
  end

  # ============================================================================
  # Lookups & Dynamic Data
  # ============================================================================
  get '/lookups/agencies', to: 'lookups#agencies'
  get '/lookups/divisions', to: 'lookups#divisions'
  get '/lookups/departments', to: 'lookups#departments'
  get '/lookups/units', to: 'lookups#units'
  get '/lookups/supervisors', to: 'lookups#supervisors'
  get '/lookups/employees', to: 'lookups#employees'
  get '/lookups/answer_fill', to: 'lookups#answer_fill'
  get '/lookups/filtered_options', to: 'lookups#filtered_options'
  get '/lookups/categories', to: 'lookups#categories'
  get '/lookups/tables', to: 'lookups#tables'
  get '/lookups/columns', to: 'lookups#columns'
  get '/lookups/category_values', to: 'lookups#category_values'

  # NHTSA vehicle lookup proxy (CSP blocks direct browser fetch)
  get '/api/nhtsa/makes', to: 'api/nhtsa#makes'
  get '/api/nhtsa/models', to: 'api/nhtsa#models'
end
