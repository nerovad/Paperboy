# frozen_string_literal: true

# Sidebar buttons inside a sub-application are now granted individually
# (permission_type 'feature', key "<app>:<button>" — see AppFeature). Without a
# backfill, every group that holds one of these apps would sign in tomorrow to
# an empty sidebar, so this reissues today's effective access as explicit
# grants. Admins can then take buttons away one at a time.
#
# Only the apps whose sidebars actually worked before are backfilled:
#
#   * Digital Asset Management, AIM, Data Runner — the application grant used
#     to show every button, so every button is granted.
#   * Admin Tools — its buttons were already individually granted, as
#     "dropdown" keys. Those five keys are copied across one for one, not
#     expanded. (The old keys keep working regardless; this is so the new ACL
#     section shows the truth.)
#
# Billing and Chart of Accounts are deliberately left empty. Their screens were
# system-admin-only no matter what the application grant said, so nobody loses
# access they had — and blanket-granting them here would hand real billing runs
# to whoever happened to hold the app. Grant those by hand.
#
# The key lists are inlined rather than read from AppFeature: a migration
# records what was true when it ran, and must not change meaning when someone
# adds a button next year.
class BackfillAppFeaturePermissions < ActiveRecord::Migration[8.0]
  FEATURES_BY_APP = {
    'digital_asset_management' => %w[search dashboard collections jobs workflows shares storage],
    'aim' => %w[dashboard processing_queues],
    'data_runner' => %w[manage_groups]
  }.freeze

  ADMIN_TOOL_KEYS = %w[acl manage_forms emulate data_validation lookup_tables].freeze

  def up
    FEATURES_BY_APP.each do |app_key, feature_keys|
      keys = feature_keys.map { |feature_key| "#{app_key}:#{feature_key}" }
      backfill_groups(app_key, keys)
      backfill_org_scopes(app_key, keys)
    end

    backfill_admin_tools
  end

  def down
    keys = FEATURES_BY_APP.flat_map { |app_key, features| features.map { |f| "#{app_key}:#{f}" } }
    keys += ADMIN_TOOL_KEYS.map { |key| "admin_tools:#{key}" }

    GroupPermission.where(permission_type: 'feature', permission_key: keys).delete_all
    OrgPermission.where(permission_type: 'feature', permission_key: keys).delete_all
  end

  private

  def backfill_groups(app_key, keys)
    group_ids = GroupPermission.where(permission_type: 'application', permission_key: app_key).pluck(:GroupID).uniq

    group_ids.each { |group_id| grant_group(group_id, keys) }
  end

  # Org grants cascade down the hierarchy, so the feature rows are written at
  # exactly the scope that held the application grant — no wider, no narrower.
  def backfill_org_scopes(app_key, keys)
    scopes = OrgPermission.where(permission_type: 'application', permission_key: app_key)
                          .pluck(:agency_id, :division_id, :department_id, :unit_id).uniq

    scopes.each { |scope| grant_org(scope, keys) }
  end

  # Admin Tools' buttons were already per-button grants under a different
  # permission_type, so each holder keeps exactly the buttons they held.
  def backfill_admin_tools
    ADMIN_TOOL_KEYS.each do |tool_key|
      key = ["admin_tools:#{tool_key}"]

      GroupPermission.where(permission_type: 'dropdown', permission_key: tool_key)
                     .pluck(:GroupID).uniq
                     .each { |group_id| grant_group(group_id, key) }

      OrgPermission.where(permission_type: 'dropdown', permission_key: tool_key)
                   .pluck(:agency_id, :division_id, :department_id, :unit_id).uniq
                   .each { |scope| grant_org(scope, key) }
    end
  end

  def grant_group(group_id, keys)
    existing = GroupPermission.where(GroupID: group_id, permission_type: 'feature', permission_key: keys)
                              .pluck(:Permission_Key)

    (keys - existing).each do |key|
      GroupPermission.create!(group_id: group_id, permission_type: 'feature', permission_key: key)
    end
  end

  def grant_org(scope, keys)
    agency_id, division_id, department_id, unit_id = scope
    conditions = { agency_id: agency_id, division_id: division_id,
                   department_id: department_id, unit_id: unit_id }

    existing = OrgPermission.where(conditions.merge(permission_type: 'feature', permission_key: keys))
                            .pluck(:permission_key)

    (keys - existing).each do |key|
      OrgPermission.create!(conditions.merge(permission_type: 'feature', permission_key: key))
    end
  end
end
