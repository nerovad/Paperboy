class CreateUserSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_settings do |t|
      t.string :employee_id, null: false
      t.boolean :inbox_email_notifications, null: false, default: false
      t.timestamps
    end

    add_index :user_settings, :employee_id, unique: true
  end
end
