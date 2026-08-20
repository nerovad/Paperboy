# frozen_string_literal: true

module Paperboy
  # Mirrors the ACL *definitions* — groups, their permission grants, and the
  # org-level grants — across Paperboy_Dev / _Stage / _Prod, which are three
  # independent databases (Groups, Group_Permissions and org_permissions all
  # live on the default connection, not in shared GSABSS). Driven by the tasks
  # in lib/tasks/acl.rake: acl:dump here, commit db/acl.yml, acl:sync there.
  # This half writes the file; AclSeed::Sync applies it.
  #
  # Nothing is matched on an id that a single database owns:
  #   * groups by Group_Name — GroupID is an identity column and has already
  #     diverged between the three databases.
  #   * forms by class_name — see AclSeed::FormKey.
  #   * org grants by the GSABSS agency/division/department/unit ids, which are
  #     shared reference data and so mean the same thing in every environment.
  #
  # Deliberately NOT handled:
  #   * Employee_Groups — memberships are meant to differ. Dev wants you in
  #     every group to test; prod wants the real assignments.
  #   * contractors — carries password_digest, which must not leave production.
  #   * form_visibility_grants — the Inbox and Submissions visibility screen.
  #     Still per-environment; add it here if it outgrows a handful of rows.
  module AclSeed
    PATH = Rails.root.join('db/acl.yml')

    module_function

    def snapshot
      forms = FormKey.index
      { 'groups' => group_rows(forms), 'org_permissions' => org_rows(forms) }
    end

    def group_rows(forms)
      Group.order(:group_name).map do |group|
        { 'name' => group.group_name, 'description' => group.description.presence, 'permissions' => grant_rows(group, forms) }
      end
    end

    def grant_rows(group, forms)
      GroupPermission.where(group_id: group.id)
                     .order(:permission_type, :permission_key)
                     .map { |perm| { 'type' => perm.permission_type, 'key' => perm.permission_key }.merge(FormKey.identity(perm.permission_type, perm.permission_key, forms)) }
    end

    def org_rows(forms = FormKey.index)
      OrgPermission.order(:agency_id, :division_id, :department_id, :unit_id, :permission_type, :permission_key).map do |perm|
        { 'agency_id' => perm.agency_id, 'division_id' => perm.division_id, 'department_id' => perm.department_id,
          'unit_id' => perm.unit_id, 'type' => perm.permission_type, 'key' => perm.permission_key }
          .merge(FormKey.identity(perm.permission_type, perm.permission_key, forms))
      end
    end

    def load_file
      raise "#{PATH} not found — run `bin/rails acl:dump` against production first." unless PATH.exist?

      YAML.safe_load_file(PATH) || {}
    end

    # Union this environment's ACL into what db/acl.yml already holds, so the
    # file can describe every environment at once. Group names are matched
    # case-insensitively (MSSQL collation is too).
    #
    # org grants are unioned as well, because a grant made in dev is work
    # nobody should have to repeat by hand in stage and prod. They remain the
    # broadest thing in the file — one row can open a form to a whole agency —
    # so read the db/acl.yml diff before committing it, and preview the far end
    # with DRY_RUN=1. acl:org_delta lists what a merge would add.
    def merge(file_data, snapshot)
      { 'groups' => merge_groups(file_data, snapshot), 'org_permissions' => merge_org(file_data, snapshot) }
    end

    def merge_groups(file_data, snapshot)
      groups = {}
      (Array(file_data['groups']) + Array(snapshot['groups'])).each do |row|
        key = row['name'].to_s.downcase
        groups[key] = groups[key] ? merge_group(groups[key], row) : row
      end
      groups.values.sort_by { |group| group['name'].to_s }
    end

    def merge_group(base, other)
      permissions = {}
      (Array(base['permissions']) + Array(other['permissions'])).each do |perm|
        key = [perm['type'].to_s, FormKey.identity_key(perm)]
        permissions[key] = richer(permissions[key], perm)
      end
      { 'name' => base['name'], 'description' => base['description'].presence || other['description'],
        'permissions' => permissions.values.sort_by { |perm| [perm['type'].to_s, perm['key'].to_s] } }
    end

    def merge_org(file_data, snapshot)
      rows = {}
      (Array(file_data['org_permissions']) + Array(snapshot['org_permissions'])).each do |row|
        identity = org_identity(row)
        rows[identity] = richer(rows[identity], row)
      end
      rows.values.sort_by { |row| org_identity(row).map(&:to_s) }
    end

    # Two rows for the same grant disagree about the form id whenever they came
    # from different databases, and a row dumped before class_name was recorded
    # names no form at all. Keep whichever one names a class; the id is
    # rewritten on sync either way.
    def richer(existing, row)
      existing && existing['class'].present? ? existing : row
    end

    # What makes two org rows the same grant, ignoring the local form id.
    def org_identity(row)
      [row['agency_id'], row['division_id'], row['department_id'], row['unit_id'],
       row['type'], FormKey.identity_key(row)].map(&:presence)
    end

    # org grants present in this environment but absent from db/acl.yml.
    def org_delta
      have = Array(load_file['org_permissions']).to_set { |row| org_identity(row) }
      org_rows.reject { |row| have.include?(org_identity(row)) }
    end

    def org_key(agency, division, department, unit, type, key)
      [agency, division, department, unit, type, key].map(&:presence)
    end

    def org_attrs(key)
      { agency_id: key[0], division_id: key[1], department_id: key[2], unit_id: key[3],
        permission_type: key[4], permission_key: key[5] }
    end

    def org_label(key)
      "#{key[0..3].compact.join('/')} → #{key[4]}/#{key[5]}"
    end

    # Org keys hold nils, so they cannot be compared directly.
    def sorted(keys)
      keys.sort_by { |key| key.map(&:to_s) }
    end
  end
end
