class CreateGroupPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :group_permissions do |t|
      t.bigint :group_id, null: false
      t.string :permission_type, limit: 50, null: false
      t.string :permission_key, limit: 255, null: false
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end

    add_index :group_permissions, [:group_id, :permission_type, :permission_key], unique: true, name: "idx_group_permissions_unique"
    add_foreign_key :group_permissions, :groups
  end
end
