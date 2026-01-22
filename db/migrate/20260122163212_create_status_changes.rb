class CreateStatusChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :status_changes do |t|
      t.string :trackable_type, null: false
      t.bigint :trackable_id, null: false
      t.string :from_status
      t.string :to_status, null: false
      t.string :changed_by_id
      t.string :changed_by_name
      t.text :notes

      t.timestamps
    end

    add_index :status_changes, [:trackable_type, :trackable_id]
    add_index :status_changes, :changed_by_id
  end
end
