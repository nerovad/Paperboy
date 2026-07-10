class ReplaceSpanWithAllBudgetUnits < ActiveRecord::Migration[8.0]
  # Span letters B-E were derivable from the budget_units/locations lists;
  # the only real information was 'A' (all budget units), which becomes an
  # explicit flag. Guarded with column_exists? because Dev was partially
  # migrated by hand before this migration existed.
  def up
    add_column :authorized_approvers, :all_budget_units, :boolean, default: false, null: false unless column_exists?(:authorized_approvers, :all_budget_units)

    return unless column_exists?(:authorized_approvers, :span)

    execute "UPDATE authorized_approvers SET all_budget_units = 1 WHERE span = 'A'"
    remove_column :authorized_approvers, :span
  end

  def down
    add_column :authorized_approvers, :span, :string
    execute "UPDATE authorized_approvers SET span = 'A' WHERE all_budget_units = 1"
    remove_column :authorized_approvers, :all_budget_units
  end
end
