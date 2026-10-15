# frozen_string_literal: true

# Duplicates (#131): an invoice with the same vendor, invoice number and total
# as an earlier one is flagged for AIM staff (duplicate_of_id). The details
# last checked are kept (duplicate_checked_key), so it is checked again only
# when they change and "not a duplicate" sticks. A replacement names the
# invoice it replaces (replaces_invoice_id).
class AddDuplicateColumnsToAimInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.invoices', :duplicate_of_id, :bigint
    add_column 'aim.invoices', :duplicate_checked_key, :string, limit: 450
    add_column 'aim.invoices', :replaces_invoice_id, :bigint
    add_index 'aim.invoices', :invoice_total, name: 'index_aim_invoices_on_invoice_total'
  end
end
