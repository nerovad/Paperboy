# frozen_string_literal: true

# app/models/app_feature.rb
#
# The catalog of individually grantable controls *inside* a sub-application.
#
# ACL > Applications decides whether a group may open Billing at all; this
# decides which of Billing's sidebar buttons they get once they are in. Grants
# are ordinary Group_Permissions / org_permissions rows with
# permission_type 'feature' and permission_key "<app_key>:<feature_key>", so
# they flow through the same org → group cascade as every other permission
# (see ApplicationController#load_user_permissions).
#
# Admin Tools already had per-button grants, issued as "dropdown" keys back
# when its screens hung off the profile menu. Those three keep working: each
# entry names its +legacy_key+ and ApplicationHelper#can_use_app_feature?
# accepts either. New apps only need the feature grant.
#
# Not a database model — it is a registry, and lives in app/models because
# that is where RegistryTable and the other catalogs live.
class AppFeature
  FEATURES = {
    'admin_tools' => [
      { key: 'acl',             label: 'ACL',             legacy_key: 'acl' },
      { key: 'manage_forms',    label: 'Manage Forms',    legacy_key: 'manage_forms' },
      { key: 'emulate',         label: 'Emulate',         legacy_key: 'emulate' }
    ],
    'billing' => [
      { key: 'reporting_period',    label: 'Reporting Period' },
      { key: 'data_refresh',        label: 'Refresh Data' },
      { key: 'enable_billing',      label: 'Enable Billing' },
      { key: 'run_monthly_billing', label: 'Run Billing' },
      { key: 'billing_audit',       label: 'Billing Audit' },
      { key: 'view_billing',        label: 'View Billing' },
      { key: 'print_reports',       label: 'Print Billing Reports' },
      { key: 'view_reports',        label: 'View Billing Reports' },
      { key: 'email_recipients',    label: 'Email Recipient List' },
      { key: 'email_subjects',      label: 'Email Subject List' },
      { key: 'email_reports',       label: 'Email Billing Reports' },
      { key: 'archive_reports',     label: 'Archive Billing Reports' }
    ],
    'p2m' => [
      { key: 'stage_data', label: 'Post Production' },
      { key: 'oms_status', label: 'OMS Status' },
      { key: 'data_refresh', label: 'Upload Billing Data' }
    ],
    # Keys match Coa::BaseController#coa_route_collection_name, which is also
    # how a request is mapped back to its grant.
    'coa' => [
      { key: 'billing_lookup',    label: 'Billing Lookup' },
      { key: 'customer_lookup',   label: 'Customer Lookup' },
      { key: 'agencies',          label: 'Agencies' },
      { key: 'divisions',         label: 'Divisions' },
      { key: 'departments',       label: 'Departments' },
      { key: 'units',             label: 'Units' },
      { key: 'sub_units',         label: 'Sub Units' },
      { key: 'activities',        label: 'Activities' },
      { key: 'functions',         label: 'Functions' },
      { key: 'funds',             label: 'Funds' },
      { key: 'major_programs',    label: 'Major Programs' },
      { key: 'objects',           label: 'Objects' },
      { key: 'object_inferences', label: 'Object Inferences' },
      { key: 'phases',            label: 'Phases' },
      { key: 'programs',          label: 'Programs' },
      { key: 'revenue_sources',   label: 'Revenue Sources' },
      { key: 'tasks',             label: 'Tasks' }
    ],
    'digital_asset_management' => [
      { key: 'search',      label: 'Search (quick and advanced)' },
      { key: 'dashboard',   label: 'Dashboard' },
      { key: 'collections', label: 'Collections' },
      { key: 'jobs',        label: 'Jobs' },
      { key: 'workflows',   label: 'Workflows' },
      { key: 'shares',      label: 'My Shares' },
      { key: 'storage',     label: 'Storage' }
    ],
    'aim' => [
      { key: 'dashboard',         label: 'Dashboard' },
      { key: 'processing_queues', label: 'Processing Queues' }
    ],
    # Data Runner's sidebar is a live list of DSLs rather than fixed buttons,
    # so only its standing control is fixed here. Every DSL is grantable too —
    # see +data_runner_dsl_features+, which reads the catalog at call time and
    # is appended by +for+.
    'data_runner' => [
      { key: 'manage_groups', label: 'Create and manage DSL groups' }
    ]
  }.freeze

  # A DSL's feature key. Prefixed so a DSL can never be named the same thing as
  # one of Data Runner's standing controls and quietly grant it.
  DSL_KEY_PREFIX = 'dsl_'

  class << self
    # The features an app declares, in sidebar order. Unknown app keys — and
    # apps with nothing worth splitting up, like Print Production — return [].
    #
    # Data Runner's list is part fixed and part catalog: its sidebar *is* the
    # DSL list, so the DSLs are grantable one by one alongside the standing
    # control above them.
    def for(app_key)
      FEATURES.fetch(app_key.to_s, []) + (app_key.to_s == 'data_runner' ? data_runner_dsl_features : [])
    end

    # One grant per DSL, read from the catalog rather than declared here — a
    # DSL is a file in config/data_runner/dsl, so a new one is grantable the
    # moment it lands. Labelled by group so the ACL screen reads the way the
    # sidebar does.
    def data_runner_dsl_features
      DslCatalog.entries.map do |entry|
        label = entry.group.present? ? "#{entry.group.humanize}: #{entry.key}" : entry.key
        { key: dsl_key(entry.slug), label: label }
      end
    end

    def dsl_key(slug)
      "#{DSL_KEY_PREFIX}#{slug}"
    end

    def permission_key(app_key, feature_key)
      "#{app_key}:#{feature_key}"
    end

    def find(app_key, feature_key)
      self.for(app_key).find { |feature| feature[:key] == feature_key.to_s }
    end

    # The old "dropdown" grant an Admin Tools button still honours, or nil.
    def legacy_key(app_key, feature_key)
      find(app_key, feature_key)&.dig(:legacy_key)
    end

    # Every permission_key an app can issue. Used by the backfill migration and
    # by Paperboy::AppDestroyer when an app is removed.
    def permission_keys_for(app_key)
      self.for(app_key).map { |feature| permission_key(app_key, feature[:key]) }
    end
  end
end
