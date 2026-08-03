# frozen_string_literal: true

# app/helpers/admin_tools_helper.rb
#
# The Admin Tools app: ACL, Manage Forms, Emulate, Data Validation and Lookup
# Tables. These used to hang off the profile dropdown's "Admin" button as a tab
# bar; they are now buttons in the Admin Tools sidebar. Only the entry point
# moved — each screen kept its original route, controller and ACL grant.
module AdminToolsHelper
  # The screens that make up the app, in sidebar order. Because the tools are
  # not in an admin_tools/ controller namespace, each one names the controllers
  # it owns; that is how a request is matched back to its sidebar button (and
  # to the app itself, see ApplicationHelper#current_app_key). `route` is the
  # path helper the button links to.
  ADMIN_TOOLS = [
    { key: 'acl', label: 'ACL', route: :acl_index_path,
      blurb: 'Groups, members and permissions by organization hierarchy.',
      controllers: %w[acl] },
    { key: 'manage_forms', label: 'Manage Forms', route: :form_templates_path,
      blurb: 'Build, edit, archive and route form templates.',
      controllers: %w[form_templates form_visibility_grants] },
    { key: 'emulate', label: 'Emulate', route: :new_admin_impersonation_path,
      blurb: 'Sign in as another employee to see what they see.',
      controllers: %w[admin/impersonations] },
    { key: 'data_validation', label: 'Data Validation', route: :admin_data_validation_index_path,
      blurb: 'Find employee records with missing or malformed data.',
      controllers: %w[admin/data_validation] },
    { key: 'lookup_tables', label: 'Lookup Tables', route: :lookup_tables_path,
      blurb: 'View and maintain the organization reference tables.',
      controllers: %w[lookup_tables] }
  ].freeze

  # Sidebar buttons, as { key:, label:, blurb:, path: }. Entries the current
  # user may not see are filtered out. The keys are ordinary ACL "Profile
  # Dropdown Items" grants, so a group can hold some tools without holding all
  # of them. System admins bypass.
  def admin_tools_links
    ADMIN_TOOLS.select { |tool| can_view_admin_tool?(tool[:key]) }
               .map { |tool| tool.slice(:key, :label, :blurb).merge(path: public_send(tool[:route])) }
  end

  def can_view_admin_tool?(key)
    system_admin? || current_user_dropdown_permissions.include?(key)
  end

  # Which Admin Tools screen the current request belongs to, or nil when it is
  # not one of them. Drives the sidebar's active button and the app switcher.
  def current_admin_tool_key
    ADMIN_TOOLS.find { |tool| tool[:controllers].include?(controller_path) }&.fetch(:key)
  end
end
