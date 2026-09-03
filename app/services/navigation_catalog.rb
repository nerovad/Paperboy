# frozen_string_literal: true

# Everywhere in the system a person can be sent, as opposed to every blank form
# they can fill out — that list is FormCatalog.
#
# The command palette is the one search that exists on every page of every app,
# so it has to know the whole system's navigation: the app switcher's apps and
# then each app's own sidebar — Billing's screens, DAM's Collections, COA's
# tables, Data Runner's DSLs, Admin Tools' screens, Production's bookmarks, and
# Paperboy's My Work, Reports and Settings. Somebody in Billing can type
# "collections" and land in DAM without knowing which app owns it.
#
#   NavigationCatalog.new(helpers).destinations
#   # => [#<Destination app: "Digital Asset Management", label: "Collections", …>]
#
# Every entry is filtered by exactly the check the sidebar that owns it makes,
# so the palette can never offer a door that sidebar would have hidden. Those
# checks — can_access_app?, can_use_app_feature?, aim_queue_access? and the
# rest — are all view helpers already, which is why this takes the helpers
# proxy rather than re-deriving permissions of its own.
class NavigationCatalog
  include Rails.application.routes.url_helpers

  # app  the heading a row is filed under, and matched on: "billing" finds
  #      every Billing screen
  # keywords  the other words a row answers to — an app's initials, a screen's
  #      blurb — none of which are on screen
  Destination = Data.define(:app, :label, :path, :keywords, :external)

  # What each app is called besides its name. The app switcher spells these
  # out; nobody types them that way.
  ALIASES = {
    'paperboy' => 'forms',
    'coa' => 'coa chart of accounts account codes',
    'digital_asset_management' => 'dam assets media library',
    'aim' => 'aim invoices automated invoice management',
    'p2m' => 'p2m print 2 mail print to mail',
    'data_runner' => 'dsl etl data runner',
    'billing' => 'billing charges invoices',
    'admin_tools' => 'admin administration tools',
    'print_production' => 'production shop bookmarks links'
  }.freeze

  # An app's fixed sidebar links, each behind the ACL > Application Features
  # grant its sidebar checks. Data Runner's sidebar is a live list rather than
  # fixed buttons, and COA's tables come from Coa::Tables, so neither is here.
  FEATURE_LINKS = {
    'digital_asset_management' => [
      { key: 'search', label: 'Search Assets', route: :digital_asset_management_assets_path },
      { key: 'dashboard', label: 'Dashboard', route: :digital_asset_management_dashboard_path },
      { key: 'collections', label: 'Collections', route: :digital_asset_management_collections_path },
      { key: 'jobs', label: 'Jobs', route: :digital_asset_management_jobs_path },
      { key: 'workflows', label: 'Workflows', route: :digital_asset_management_workflows_path },
      { key: 'shares', label: 'My Shares', route: :digital_asset_management_shares_path },
      { key: 'storage', label: 'Storage', route: :digital_asset_management_storage_locations_path }
    ],
    'p2m' => [
      { key: 'stage_data', label: 'Pre Production', route: :p2m_pre_production_path },
      { key: 'stage_data', label: 'Post Production', route: :p2m_stage_data_path },
      { key: 'oms_status', label: 'OMS Status', route: :p2m_oms_status_path },
      { key: 'data_refresh', label: 'Upload Billing Data', route: :p2m_data_refresh_path }
    ],
    'coa' => Coa::Tables::LOOKUPS
  }.freeze

  def initialize(view)
    @view = view
  end

  # In app-switcher order, each app's own row first and its sidebar under it.
  def destinations
    @destinations ||= view.paperboy_apps.flat_map do |app|
      [Destination.new(app: 'Application', label: app[:label], path: app[:path],
                       keywords: ALIASES.fetch(app[:key], ''), external: false),
       *within(app)]
    end
  end

  private

  attr_reader :view

  def within(app)
    rows = case app[:key]
           when 'paperboy' then paperboy_rows
           when 'admin_tools' then admin_tools_rows
           when 'billing' then billing_rows
           when 'coa' then coa_rows
           when 'digital_asset_management', 'p2m' then feature_rows(app[:key])
           when 'aim' then aim_rows
           when 'data_runner' then data_runner_rows
           when 'print_production' then production_rows
           else []
           end

    rows.map { |row| Destination.new(app: app[:label], external: false, keywords: '', **row) }
  end

  # The profile dropdown and the My Work tabs, which together are Paperboy's
  # navigation. Inbox and Submissions are tabs of one page, so each is offered
  # only to whoever the tab bar would show it to.
  def paperboy_rows
    rows = []
    rows << { label: 'Inbox', path: inbox_queue_path, keywords: 'my work queue approvals' } if dropdown?('inbox')
    rows << { label: 'Submissions', path: submissions_path, keywords: 'my work submitted' } if dropdown?('submissions')
    rows << { label: 'Records', path: records_path, keywords: 'my work tables' } if view.records_portal_path
    rows << { label: 'Reports', path: reports_path } if dropdown?('reports')
    rows << { label: 'Dashboards', path: dashboards_path } if dropdown?('dashboards')
    rows << { label: 'Authorizations', path: select_authorization_console_index_path } if view.available_authorization_consoles.any?
    rows << { label: 'Settings', path: settings_path } if dropdown?('settings')
    rows << { label: 'Help', path: help_path } if dropdown?('help')
    rows
  end

  def admin_tools_rows
    view.admin_tools_links.map { |tool| { label: tool[:label], path: tool[:path], keywords: tool[:blurb] } }
  end

  # Only the screens. The sidebar's other entries post an operation rather than
  # going anywhere, and the palette navigates.
  def billing_rows
    view.billing_sidebar_items.select { |item| item[:page] }
                              .map { |item| { label: item[:label], path: item[:path] } }
  end

  # The two lookups, then every table the grants allow.
  def coa_rows
    feature_rows('coa') +
      Coa::Tables::ALL.select { |table| feature?('coa', table[:collection]) }
                      .map { |table| { label: table[:label], path: public_send("coa_#{table[:collection]}_path"), keywords: 'table' } }
  end

  def aim_rows
    rows = []
    rows << { label: 'Dashboard', path: aim_dashboard_path } if feature?('aim', 'dashboard')
    return rows unless view.aim_queue_access?

    rows + Aim::InvoiceDirectoryService::BACKEND_QUEUES.map do |queue, config|
      { label: config[:label], path: aim_invoices_path(queue: queue), keywords: config[:description].to_s }
    end
  end

  def feature_rows(app_key)
    FEATURE_LINKS.fetch(app_key, []).select { |link| feature?(app_key, link[:key]) }
                                    .map { |link| { label: link[:label], path: public_send(link[:route]) } }
  end

  # Every DSL the viewer is granted, by name, because that is what the Data
  # Runner sidebar is. Each one is a grant of its own under ACL > Application
  # Features, so this asks the helper the sidebar asks rather than reading the
  # catalog straight.
  def data_runner_rows
    rows = view.permitted_dsls.map do |entry|
      { label: entry.key, path: data_runner_dsl_path(entry.slug), keywords: "#{entry.group} #{entry.slug}" }
    end
    return rows unless feature?('data_runner', 'manage_groups')

    rows + [{ label: 'New DSL Group', path: data_runner_new_dsl_group_path },
            { label: 'Import Database Table', path: new_data_runner_database_dsls_path }]
  end

  def production_rows
    Production::Links::ALL.map do |link|
      { label: link[:label], path: link[:url], keywords: link[:title].to_s, external: true }
    end
  end

  def dropdown?(key)
    view.system_admin? || view.current_user_dropdown_permissions.include?(key)
  end

  def feature?(app_key, feature_key)
    view.can_use_app_feature?(app_key, feature_key)
  end
end
