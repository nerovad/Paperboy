# frozen_string_literal: true

# A person's home unit comes from GSABSS and cannot be taken away, but it can
# be hidden: they then see nothing in that BU (Joshua, 2026-09-25).
class AddHiddenToAimUserBudgetUnits < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.user_budget_units', :hidden, :boolean, null: false, default: false
  end
end
