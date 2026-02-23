class CreateGroupPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :Group_Permissions, primary_key: [:GroupID, :Permission_Type, :Permission_Key] do |t|
      t.integer :GroupID, null: false
      t.string :Permission_Type, limit: 50, null: false
      t.string :Permission_Key, limit: 255, null: false
      t.datetime :Created_At, default: -> { 'GETDATE()' }, null: false
    end
  end
end
