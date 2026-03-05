class CreateOrgPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :org_permissions do |t|
      t.string :agency_id
      t.string :division_id
      t.string :department_id
      t.string :unit_id
      t.string :permission_type, null: false
      t.string :permission_key, null: false
      t.timestamps
    end

    add_index :org_permissions, [:agency_id, :division_id, :department_id, :unit_id, :permission_type, :permission_key],
              unique: true, name: 'idx_org_permissions_unique'
    add_index :org_permissions, :agency_id
    add_index :org_permissions, :division_id
    add_index :org_permissions, :department_id
    add_index :org_permissions, :unit_id
  end
end
