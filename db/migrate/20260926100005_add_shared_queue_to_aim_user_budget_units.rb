# frozen_string_literal: true

# Whether a person picks up a BU's shared queue: its unowned ready invoices,
# which they may open and approve. Off unless switched on, for the home unit
# too; a BU Admin of the BU always has it (Joshua, 2026-09-25).
class AddSharedQueueToAimUserBudgetUnits < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.user_budget_units', :shared_queue, :boolean, null: false, default: false
  end
end
