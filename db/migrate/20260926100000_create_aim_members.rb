# frozen_string_literal: true

# AIM user administration (item a.1): the people who work AIM, added on the
# Admin screen rather than inferred from group membership. The person is a
# GSABSS employee id; names and units are read from GSABSS, never copied.
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimMembers < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.members' do |t|
      t.integer :employee_id, null: false
      t.string :added_by, limit: 255
      t.timestamps
    end

    add_index 'aim.members', :employee_id, unique: true, name: 'index_aim_members_on_employee_id'
  end
end
