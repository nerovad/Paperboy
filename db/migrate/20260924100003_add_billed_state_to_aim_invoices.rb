# frozen_string_literal: true

# What the billing table last showed for each invoice. The worker upserts the
# billing row whenever an invoice's state differs from this, so every invoice
# that arrives is billed and its status follows it. AIM v2.
class AddBilledStateToAimInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.invoices', :billed_state, :string, limit: 40
  end
end
