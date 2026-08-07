# frozen_string_literal: true

# app/helpers/application_helper.rb
module ApplicationHelper
  def syntax_highlight(source, language: nil, filename: nil)
    lexer = Rouge::Lexer.find_fancy(language || filename, source) || Rouge::Lexers::PlainText
    formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')

    formatter.format(lexer.lex(source.to_s)).html_safe
  end

  def current_user
    session[:user]
  end

  def format_phone(digits)
    d = digits.to_s.gsub(/\D/, '')
    return digits if d.length != 10

    "#{d[0, 3]}-#{d[3, 3]}-#{d[6, 4]}"
  end

  def format_pst(time, format: :short)
    return nil unless time

    l(time.in_time_zone('Pacific Time (US & Canada)'), format: format)
  end

  def environment_badge(host: request.host, rails_env: Rails.env)
    env_name = rails_env.to_s

    if localhost_host?(host)
      { label: 'LOCALHOST', css_class: 'is-localhost' }
    elsif env_name == 'development'
      { label: 'Development', css_class: 'is-development' }
    elsif env_name == 'staging'
      { label: 'Stage', css_class: 'is-staging' }
    end
  end

  def system_admin?
    current_user_group_names.include?('system_admins')
  end

  # The Admin Tools app's screens — the list, its ACL filtering and the
  # request-to-tool matching — live in AdminToolsHelper.

  # Whether to offer the 300A Summary. It is reached from the OSHA Reporting
  # form itself rather than the profile dropdown, and the 300 Log moved to
  # Records (see OshaReport's registry_table) — but all three still share the
  # single 'osha_log' grant, which the 300A controller and the Records table
  # each enforce on their own.
  def osha_300a_visible?
    system_admin? || current_user_dropdown_permissions.include?('osha_log')
  end

  # Display name for an org level as the given agency names it — HCA reverses
  # "division" and "department" (see OrgLabels). Pass the agency the record or
  # filter belongs to; a nil agency yields the canonical label.
  def org_label(level, agency)
    OrgLabels.label(level, agency)
  end

  # Records tables (see Registry) the current user may open, in declared order.
  # Access mirrors the standalone P-Card gate: system admins see all; everyone
  # else needs the table's group grant, its ACL dropdown key, or a per-table
  # grant from the ACL "Records Access" section.
  def records_portal_tables
    RegistryTable.all.select { |table| can_access_record_table?(table) }
  end

  # The record_view grant is keyed by slug and so covers every Records table,
  # including the form-backed ones that declare neither a group permission nor
  # a dropdown key — without it those tables are reachable by system admins
  # alone, no matter what an admin ticks in the ACL.
  def can_access_record_table?(table)
    return true if system_admin?
    return true if table.permission.present? && current_user_group_names.include?(table.permission)
    return true if current_user_record_view_permission_keys.include?(table.slug)

    table.dropdown_key.present? && current_user_dropdown_permissions.include?(table.dropdown_key)
  end

  # Whether the current user may edit a Records table's rows inline. Editing is
  # a grant of its own — being able to open a grid never implies being able to
  # rewrite it — so a viewer sees a read-only table until an admin ticks the
  # table in the ACL "Records Editing" section. System admins bypass, matching
  # every other permission gate.
  def can_edit_record_table?(table)
    return false unless can_access_record_table?(table)

    system_admin? || current_user_record_edit_permission_keys.include?(table.slug)
  end

  # Landing path for the Records pillar, or nil when the user may open no table.
  def records_portal_path
    records_portal_tables.any? ? records_path : nil
  end

  # The sub-applications reachable from the sidebar app switcher. Each entry
  # is { key:, label:, path: }; entries the current user may not see are
  # filtered out. Paperboy is the always-available base app; the secondary
  # apps are gated by the ACL "Applications" section (system admins bypass),
  # matching the profile-dropdown/form permission model.
  def paperboy_apps
    apps = [{ key: 'paperboy', label: 'Paperboy', path: root_path }]
    apps << { key: 'data_runner', label: 'Data Runner', path: data_runner_root_path } if can_access_app?('data_runner')
    apps << { key: 'coa', label: 'Chart of Accounts', path: coa_root_path } if can_access_app?('coa')
    apps << { key: 'digital_asset_management', label: 'Digital Asset Management', path: digital_asset_management_root_path } if can_access_app?('digital_asset_management')
    apps << { key: 'aim', label: 'Automated Invoice Management', path: aim_root_path } if can_access_app?('aim')
    apps << { key: 'print_production', label: 'Print Production', path: print_production_root_path } if can_access_app?('print_production')
    apps << { key: 'billing', label: 'Billing', path: billing_root_path } if can_access_app?('billing')
    apps << { key: 'admin_tools', label: 'Admin Tools', path: admin_tools_root_path } if can_access_app?('admin_tools')
    [apps.first, *apps.drop(1).sort_by { |app| app.fetch(:label).downcase }]
  end

  # Whether the current user may reach an app-switcher sub-application. System
  # admins see everything; everyone else needs an ACL "application" grant for
  # the given key (via group or org-level permission).
  #
  # Admin Tools is the exception: it is a container for screens that already
  # carry their own ACL grants, so holding any one of those is enough to get
  # in. Without that, moving the screens under the app would have locked out
  # every group that holds, say, only the 'acl' key. The 'admin_tools'
  # application grant still works as a way in of its own.
  def can_access_app?(key)
    return true if system_admin?
    return true if key == 'admin_tools' && admin_tools_links.any?

    current_user_application_permission_keys.include?(key)
  end

  # Which sub-application the current request belongs to, keyed to
  # +paperboy_apps+. Defaults to Paperboy for everything outside the
  # data_runner/ and coa/ controller namespaces.
  #
  # The Admin Tools screens are the one app whose controllers are not in a
  # matching namespace — they kept their original top-level routes — so they
  # are matched by name instead (see +ADMIN_TOOLS+).
  def current_app_key
    if controller_path.start_with?('admin_tools/') || current_admin_tool_key
      'admin_tools'
    elsif controller_path.start_with?('data_runner/')
      'data_runner'
    elsif controller_path.start_with?('coa/')
      'coa'
    elsif controller_path.start_with?('digital_asset_management/')
      'digital_asset_management'
    elsif controller_path.start_with?('aim/')
      'aim'
    elsif controller_path.start_with?('print_production/')
      'print_production'
    elsif controller_path.start_with?('billing/')
      'billing'
    else
      'paperboy'
    end
  end

  def fetch_acl_groups
    Group.order(:Group_Name).pluck(:Group_Name, :GroupID)
  rescue StandardError
    []
  end

  # Catalog of dynamic forms and their fields, for the column customizer's
  # "add a field from a form" picker. Shape:
  #   { "Leave Of Absence" => { "class_name" => "LeaveOfAbsenceForm",
  #       "fields" => [{ "name" => "reason", "label" => "Leave Reason" }, ...] } }
  # Only fields backed by a real column on the form's table are offered
  # (excludes media/information fields and anything not persisted as a column).
  def table_field_catalog
    non_display = %w[media_attachment information]
    catalog = {}

    FormTemplate.includes(:form_fields).order(:name).each do |template|
      klass = template.class_name.safe_constantize
      next unless klass.respond_to?(:column_names)

      columns = klass.column_names

      fields = template.form_fields
                       .reject { |f| non_display.include?(f.field_type) }
                       .select { |f| columns.include?(f.field_name.to_s) }
                       .map { |f| { 'name' => f.field_name, 'label' => f.label.presence || f.field_name.to_s.tr('_', ' ').titleize } }
                       .uniq { |h| h['name'] }

      next if fields.empty?

      catalog[template.name] = { 'class_name' => template.class_name, 'fields' => fields }
    end

    catalog
  rescue StandardError => e
    Rails.logger.warn("table_field_catalog failed: #{e.class}: #{e.message}")
    {}
  end

  private

  def localhost_host?(host)
    ['localhost', '127.0.0.1', '::1'].include?(host.to_s)
  end
end
