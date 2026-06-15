class CreateFormVisibilityGrants < ActiveRecord::Migration[8.0]
  def change
    create_table :form_visibility_grants do |t|
      t.string  :form_type,    null: false   # model class name, e.g. "CriticalInformationReporting"
      t.string  :grantee_type, null: false   # "group" (employee reserved for future use)
      t.integer :group_id
      t.integer :employee_id

      t.timestamps
    end

    add_index :form_visibility_grants, :form_type
    add_index :form_visibility_grants, [:grantee_type, :group_id]
  end
end
