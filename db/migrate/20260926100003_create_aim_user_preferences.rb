# frozen_string_literal: true

# AIM Admin / Approver mode (item a.2): the mode an AIM Admin or Staff member
# starts in. The switch itself lives in the session; this is only the default.
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.user_preferences' do |t|
      t.integer :employee_id, null: false
      t.string :start_mode, limit: 20, null: false, default: 'admin'
      t.timestamps
    end

    add_index 'aim.user_preferences', :employee_id, unique: true, name: 'index_aim_user_preferences_on_employee_id'
  end
end
