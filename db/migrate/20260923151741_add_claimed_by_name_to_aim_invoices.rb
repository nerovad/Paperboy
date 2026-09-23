# frozen_string_literal: true

# Who holds an invoice, by name as well as by address, so the review page can
# say "Dana Reyes claimed this invoice" from the row rather than from the
# .claim.json file 5.7c stops reading.
class AddClaimedByNameToAimInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.invoices', :claimed_by_name, :string
  end
end
