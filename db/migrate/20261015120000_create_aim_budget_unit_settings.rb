# frozen_string_literal: true

# Per-BU settings (#131), starting with the high-dollar second approval: an
# invoice over second_approval_over goes, after its first approval, to the
# named second approver. The invoice keeps who gave the first approval and
# when. Alerts' per-BU overrides join this table later.
#
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimBudgetUnitSettings < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.budget_unit_settings' do |t|
      t.string :agency_id, limit: 10, null: false
      t.string :budget_unit, limit: 10, null: false
      t.decimal :second_approval_over, precision: 15, scale: 2
      t.integer :second_approver_employee_id
      t.string :updated_by, limit: 255
      t.timestamps
    end
    add_index 'aim.budget_unit_settings', %i[agency_id budget_unit], unique: true,
                                                                     name: 'index_aim_budget_unit_settings_on_agency_and_unit'

    add_column 'aim.invoices', :first_approved_by, :string, limit: 255
    add_column 'aim.invoices', :first_approved_at, :datetime
  end
end
