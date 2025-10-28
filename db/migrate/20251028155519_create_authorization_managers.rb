# db/migrate/XXXXXX_create_authorization_managers.rb
class CreateAuthorizationManagers < ActiveRecord::Migration[7.0]
  def change
    create_table :authorization_managers do |t|
      t.string :employee_id, null: false
      t.string :department_id, null: false
      t.timestamps
    end
    
    add_index :authorization_managers, [:employee_id, :department_id], unique: true
  end
end
