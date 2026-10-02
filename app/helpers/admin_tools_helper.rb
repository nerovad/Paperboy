# frozen_string_literal: true

# app/helpers/admin_tools_helper.rb
#
# The Admin Tools app: ACL, Manage Forms and Emulate. These used to hang off
# the profile dropdown's "Admin" button as a tab bar; they are now buttons in
# the Admin Tools sidebar. Only the entry point moved — each screen kept its
# original route, controller and ACL grant.
module AdminToolsHelper
  # The screens that make up the app, in sidebar order. Because the tools are
  # not in an admin_tools/ controller namespace, each one names the controllers
  # it owns; that is how a request is matched back to its sidebar button (and
  # to the app itself, see ApplicationHelper#current_app_key). `route` is the
  # path helper the button links to.
  ADMIN_TOOLS = [
    { key: 'acl', label: 'ACL', route: :acl_index_path,
      blurb: 'Groups, members and permissions by organization hierarchy.',
      controllers: %w[acl dam_access_rules] },
    { key: 'manage_forms', label: 'Manage Forms', route: :form_templates_path,
      blurb: 'Build, edit, archive and route form templates.',
      controllers: %w[form_templates form_visibility_grants] },
    { key: 'emulate', label: 'Emulate', route: :new_admin_impersonation_path,
      blurb: 'Sign in as another employee or contractor to see what they see.',
      controllers: %w[admin/impersonations] }
  ].freeze

  # Sidebar buttons, as { key:, label:, blurb:, path: }. Entries the current
  # user may not see are filtered out, so a group can hold some tools without
  # holding all of them. System admins bypass.
  def admin_tools_links
    ADMIN_TOOLS.select { |tool| can_view_admin_tool?(tool[:key]) }
               .map { |tool| tool.slice(:key, :label, :blurb).merge(path: public_send(tool[:route])) }
  end

  # A contractor's entry in the Emulate picker. Inactive and expired accounts
  # stay listed -- seeing what a locked-out contractor would see is a fair
  # reason to emulate them -- but are flagged so nobody picks one by mistake.
  def contractor_emulation_label(contractor)
    label = "#{contractor.first_name} #{contractor.last_name} (#{contractor.email})"
    if !contractor.active?
      "#{label} - inactive"
    elsif contractor.expired?
      "#{label} - expired"
    else
      label
    end
  end

  def admin_tools_form_templates
    @admin_tools_form_templates ||= Forms::Template.order(:name).select(:id, :name).to_a
  end

  # Admin Tools is now one of several apps whose sidebar buttons are granted
  # individually (see AppFeature). These three predate that section and were
  # issued as ACL "Profile Dropdown Items"; can_use_app_feature? honours both
  # the old key and the new one, so existing grants needed no migration.
  def can_view_admin_tool?(key)
    can_use_app_feature?('admin_tools', key)
  end

  # Which Admin Tools screen the current request belongs to, or nil when it is
  # not one of them. Drives the sidebar's active button and the app switcher.
  def current_admin_tool_key
    ADMIN_TOOLS.find { |tool| tool[:controllers].include?(controller_path) }&.fetch(:key)
  end

  # The ACL screen is a small administration app of its own. Keep the dynamic
  # application-feature links here so they remain available while visiting any
  # ACL page, including DAM rules and an individual group's permissions.
  def acl_sidebar_application_features
    features = AclController::APPLICATION_ITEMS.filter_map do |app|
      next if AppFeature.for(app[:key]).empty?

      { label: app[:label], path: org_permissions_acl_index_path(anchor: "application-features-#{app[:key]}") }
    end
    features.sort_by { |item| item[:label].downcase }
  end

  def acl_sidebar_groups
    Group.all.sort_by { |group| group.group_name.to_s.downcase }
  end

  def acl_sidebar_group_page?(group)
    current_page?(acl_path(group)) || request.path.start_with?("#{acl_path(group)}/")
  end
end
