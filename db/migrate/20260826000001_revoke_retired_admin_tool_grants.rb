# frozen_string_literal: true

# Data Validation and Lookup Tables are gone: both screens went unused, so
# their controllers, views and routes were deleted and AppFeature no longer
# lists them.
#
# Their grants have to go with them. Left behind they are invisible orphans —
# nothing renders a permission whose ACL item no longer exists — and they would
# silently re-grant access to whoever still holds them if either key is ever
# reused (the same reasoning as Paperboy::AppDestroyer).
#
# Both spellings are revoked: the modern feature key "admin_tools:<tool>" and
# the older "dropdown" key from when these screens hung off the profile menu.
#
# The keys are inlined rather than read from AppFeature, which no longer knows
# them; a migration records what was true when it ran.
class RevokeRetiredAdminToolGrants < ActiveRecord::Migration[8.0]
  RETIRED_KEYS = %w[data_validation lookup_tables].freeze

  def up
    feature_keys = RETIRED_KEYS.map { |key| "admin_tools:#{key}" }

    GroupPermission.where(permission_type: 'feature', permission_key: feature_keys).delete_all
    OrgPermission.where(permission_type: 'feature', permission_key: feature_keys).delete_all

    GroupPermission.where(permission_type: 'dropdown', permission_key: RETIRED_KEYS).delete_all
    OrgPermission.where(permission_type: 'dropdown', permission_key: RETIRED_KEYS).delete_all
  end

  # The screens are deleted, so there is nothing to grant access back to.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
