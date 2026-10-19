# frozen_string_literal: true

# Acknowledging a rejected or deleted invoice (#169): AIM staff say "seen, and
# it is fine", and it leaves the Rejected or Deleted list, still found by
# Search older invoices. Shared: one person's acknowledgement clears it for
# everyone. Cleared by any later move of the invoice's state, so a restored
# invoice rejected again comes back as new.
#
# Every invoice already rejected or deleted starts unacknowledged. A second
# run, or a run after a crash, adds only what is missing.
#
# Explicit index names: see test/lib/aim/schema_conventions_test.rb.
class AddAcknowledgedToAimInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column 'aim.invoices', :acknowledged_at, :datetime unless column_exists?('aim.invoices', :acknowledged_at)
    add_column 'aim.invoices', :acknowledged_by, :string, limit: 255 unless column_exists?('aim.invoices', :acknowledged_by)
    add_index 'aim.invoices', %i[state acknowledged_at], name: 'index_aim_invoices_on_state_and_acknowledged_at',
                                                         if_not_exists: true
  end

  def down
    remove_index 'aim.invoices', name: 'index_aim_invoices_on_state_and_acknowledged_at', if_exists: true
    remove_column 'aim.invoices', :acknowledged_by if column_exists?('aim.invoices', :acknowledged_by)
    remove_column 'aim.invoices', :acknowledged_at if column_exists?('aim.invoices', :acknowledged_at)
  end
end
