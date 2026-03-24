class SeedDefaultPublicDropdownPermissions < ActiveRecord::Migration[8.0]
  def up
    default_keys = %w[inbox submissions settings help]

    # Grant to every existing group
    group_ids = execute("SELECT GroupID FROM Groups").map { |r| r["GroupID"] }
    group_ids.each do |gid|
      default_keys.each do |key|
        execute <<~SQL.squish
          IF NOT EXISTS (
            SELECT 1 FROM Group_Permissions
            WHERE GroupID = #{gid}
              AND Permission_Type = 'dropdown'
              AND Permission_Key = '#{key}'
          )
          INSERT INTO Group_Permissions (GroupID, Permission_Type, Permission_Key, Created_At)
          VALUES (#{gid}, 'dropdown', '#{key}', GETDATE())
        SQL
      end
    end

    # Grant to every distinct org scope that has any permissions
    scopes = execute(<<~SQL.squish)
      SELECT DISTINCT agency_id, division_id, department_id, unit_id
      FROM org_permissions
    SQL

    # Also ensure every agency has a row
    agencies = execute("SELECT agency_id FROM agencies")
    agency_ids = agencies.map { |r| r["agency_id"] }

    all_scopes = scopes.map { |r| [r["agency_id"], r["division_id"], r["department_id"], r["unit_id"]] }.to_set
    agency_ids.each { |aid| all_scopes << [aid, nil, nil, nil] }

    all_scopes.each do |agency_id, division_id, department_id, unit_id|
      default_keys.each do |key|
        a = agency_id ? "'#{agency_id}'" : "NULL"
        dv = division_id ? "'#{division_id}'" : "NULL"
        dp = department_id ? "'#{department_id}'" : "NULL"
        u = unit_id ? "'#{unit_id}'" : "NULL"

        execute <<~SQL.squish
          IF NOT EXISTS (
            SELECT 1 FROM org_permissions
            WHERE ISNULL(agency_id, '') = ISNULL(#{a}, '')
              AND ISNULL(division_id, '') = ISNULL(#{dv}, '')
              AND ISNULL(department_id, '') = ISNULL(#{dp}, '')
              AND ISNULL(unit_id, '') = ISNULL(#{u}, '')
              AND permission_type = 'dropdown'
              AND permission_key = '#{key}'
          )
          INSERT INTO org_permissions (agency_id, division_id, department_id, unit_id, permission_type, permission_key, created_at, updated_at)
          VALUES (#{a}, #{dv}, #{dp}, #{u}, 'dropdown', '#{key}', GETDATE(), GETDATE())
        SQL
      end
    end
  end

  def down
    # Only remove settings and help (inbox/submissions may have been manually configured before)
    execute "DELETE FROM Group_Permissions WHERE Permission_Type = 'dropdown' AND Permission_Key IN ('settings', 'help')"
    execute "DELETE FROM org_permissions WHERE permission_type = 'dropdown' AND permission_key IN ('settings', 'help')"
  end
end
