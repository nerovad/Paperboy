# frozen_string_literal: true

# One row per AIM invoice, from the moment the watcher mints its batch id.
# The row is where the invoice's state lives; the files on the share are its
# documents and nothing more.
class CreateAimInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.invoices' do |t|
      # The processing id the watcher mints: one per invoice, and the name of
      # its folder on the share.
      t.string :batch_id, null: false, limit: 255
      # Vendor, invoice number, total and date as one string -- the duplicate
      # key. Phase 7 fills and indexes it.
      t.string :business_key, limit: 450
      t.string :budget_unit, limit: 10
      t.string :submitter
      t.string :document_type, limit: 50
      # Which queue the invoice is in. Step 5.4 defines the values.
      t.string :state, null: false, limit: 50

      t.string :claimed_by
      t.datetime :claimed_at
      t.string :assigned_to
      # How the assignment was made: by a person today, by a coversheet
      # barcode later.
      t.string :assignment_source, limit: 50

      t.string :extracted_vendor_name
      t.string :vendor_name
      t.string :invoice_number, limit: 100
      t.string :order_number, limit: 100
      t.string :customer_number, limit: 100
      t.decimal :invoice_total, precision: 15, scale: 2
      t.date :invoice_date

      t.timestamps
    end

    add_index 'aim.invoices', :batch_id, unique: true, name: 'index_aim_invoices_on_batch_id'
    add_index 'aim.invoices', %i[state budget_unit], name: 'index_aim_invoices_on_state_and_budget_unit'
  end
end
