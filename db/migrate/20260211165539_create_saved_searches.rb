class CreateSavedSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :saved_searches do |t|
      t.string :employee_id, null: false
      t.string :name, null: false
      t.text :filters, null: false  # JSON-serialized hash of filter params

      t.timestamps
    end

    add_index :saved_searches, :employee_id
    add_index :saved_searches, [:employee_id, :name], unique: true
  end
end
