class RenameStatusPermissionToSubmissions < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'submissions'
      WHERE Permission_Type = 'dropdown'
        AND Permission_Key = 'status'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE Group_Permissions
      SET Permission_Key = 'status'
      WHERE Permission_Type = 'dropdown'
        AND Permission_Key = 'submissions'
    SQL
  end
end
