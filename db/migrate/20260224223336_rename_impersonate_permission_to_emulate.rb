class RenameImpersonatePermissionToEmulate < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'emulate'
      WHERE Permission_Type = 'dropdown'
        AND Permission_Key = 'impersonate'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'impersonate'
      WHERE Permission_Type = 'dropdown'
        AND Permission_Key = 'emulate'
    SQL
  end
end
