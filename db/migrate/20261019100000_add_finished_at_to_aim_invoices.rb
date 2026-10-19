# frozen_string_literal: true

# When an invoice finished (#169): the finished queues show a recent window
# and search the rest, which needs a date to window on. Exported had one
# (exported_at); Rejected, Deleted and Split did not. Set on every move into a
# finished state and cleared on the way out (Aim::Invoice, and the worker's
# Db#transition).
#
# Rows already finished are dated from their history: the event that moved
# them into their state, else exported_at, else updated_at. A second run, or
# a run after a crash, fills only rows still without a date.
#
# Fiscal's Archived list windows on fiscal_records.archived_at; exported_at
# is indexed for the Fiscal dashboard's "Exported over 30 days". Both with
# their status.
#
# Explicit index names: see test/lib/aim/schema_conventions_test.rb.
class AddFinishedAtToAimInvoices < ActiveRecord::Migration[8.1]
  FINISHED = "'exported', 'rejected', 'deleted', 'split'"

  def up
    add_column 'aim.invoices', :finished_at, :datetime unless column_exists?('aim.invoices', :finished_at)
    add_index 'aim.invoices', %i[state finished_at], name: 'index_aim_invoices_on_state_and_finished_at',
                                                     if_not_exists: true
    add_index 'aim.fiscal_records', %i[status exported_at], name: 'index_aim_fiscal_records_on_status_and_exported_at',
                                                            if_not_exists: true
    add_index 'aim.fiscal_records', %i[status archived_at], name: 'index_aim_fiscal_records_on_status_and_archived_at',
                                                            if_not_exists: true
    execute <<~SQL.squish
      UPDATE aim.invoices SET finished_at = COALESCE(
        (SELECT MAX(e.created_at) FROM aim.invoice_events e WHERE e.invoice_id = aim.invoices.id AND e.to_state = aim.invoices.state),
        exported_at, updated_at)
      WHERE state IN (#{FINISHED}) AND finished_at IS NULL
    SQL
  end

  def down
    remove_index 'aim.fiscal_records', name: 'index_aim_fiscal_records_on_status_and_archived_at', if_exists: true
    remove_index 'aim.fiscal_records', name: 'index_aim_fiscal_records_on_status_and_exported_at', if_exists: true
    remove_index 'aim.invoices', name: 'index_aim_invoices_on_state_and_finished_at', if_exists: true
    remove_column 'aim.invoices', :finished_at if column_exists?('aim.invoices', :finished_at)
  end
end
