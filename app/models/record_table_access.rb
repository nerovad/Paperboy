# frozen_string_literal: true

# Who may open and edit a Records table (see Registry), written once for both
# places that ask: ApplicationHelper, for the signed-in user of a request, and
# EmployeePermissions, for the owner of a scheduled export running in a job
# with no session. Both expose the same readers, so the rule cannot drift
# between what the grid shows and what a scheduled email sends.
#
# The includer provides #system_admin?, #current_user_group_names,
# #current_user_record_view_permission_keys,
# #current_user_record_edit_permission_keys and
# #current_user_dropdown_permissions.
module RecordTableAccess
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
end
