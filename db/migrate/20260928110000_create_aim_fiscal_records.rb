# frozen_string_literal: true

# The Fiscal stage (item f), first cut for a demo with Fiscal (2026-09-28):
# what Fiscal records about an approved invoice, kept beside it so the worker's
# pipeline is untouched. Its fields are DocuShare's: check and pay doc numbers,
# the encumbrance (BDO/DO), the coding, holds and their tags. And a Fiscal
# switch on the AIM list: who works the Fiscal queue. No database foreign keys
# and explicit index names: see test/lib/aim/schema_conventions_test.rb.
class CreateAimFiscalRecords < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.fiscal_records' do |t|
      t.bigint :invoice_id, null: false
      t.string :status, limit: 20, null: false, default: 'review'
      t.string :tag, limit: 40
      t.string :hold_reason, limit: 500
      t.string :bdo_do, limit: 100
      t.string :pay_doc_number, limit: 100
      t.string :check_number, limit: 50
      t.date :check_date
      t.decimal :credit_amount, precision: 15, scale: 2
      t.string :split_amount, limit: 100
      t.string :object_code, limit: 20
      t.string :dept_object, limit: 20
      t.string :activity, limit: 20
      t.string :function_code, limit: 20
      t.string :program, limit: 20
      t.string :phase, limit: 20
      t.string :task, limit: 20
      t.text :description
      t.datetime :exported_at
      t.datetime :archived_at
      t.string :updated_by, limit: 255
      t.timestamps
    end

    add_index 'aim.fiscal_records', :invoice_id, unique: true, name: 'index_aim_fiscal_records_on_invoice_id'
    add_index 'aim.fiscal_records', :status, name: 'index_aim_fiscal_records_on_status'
    add_column 'aim.members', :fiscal, :boolean, null: false, default: false
  end
end
