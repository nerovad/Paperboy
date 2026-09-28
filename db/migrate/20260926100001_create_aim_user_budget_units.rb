# frozen_string_literal: true

# AIM roles and BU scope (item a.2): the budget units a person works beyond
# their home unit, and the ones they are BU Admin of. The home unit is read
# from GSABSS and needs no row; a row for it only carries the BU Admin flag.
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimUserBudgetUnits < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.user_budget_units' do |t|
      t.integer :employee_id, null: false
      t.string :budget_unit, limit: 10, null: false
      t.boolean :bu_admin, null: false, default: false
      t.string :granted_by, limit: 255
      t.timestamps
    end

    add_index 'aim.user_budget_units', %i[employee_id budget_unit], unique: true,
                                                                    name: 'index_aim_user_budget_units_on_person_and_bu'
    add_index 'aim.user_budget_units', :budget_unit, name: 'index_aim_user_budget_units_on_budget_unit'
  end
end
