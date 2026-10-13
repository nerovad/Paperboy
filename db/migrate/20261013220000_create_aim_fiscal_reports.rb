# frozen_string_literal: true

# Saved Fiscal reports (#131): each processed report is numbered (its id) and
# kept with the file it made, and which invoices were in it, so it can be
# downloaded again and every invoice names the reports it was on. The file is
# purged a year on (Aim::PurgeFiscalReportsJob); the row and its invoice list
# stay.
#
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimFiscalReports < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.fiscal_reports' do |t|
      t.bigint :agency_group_id
      t.bigint :report_template_id
      t.string :layout_name, limit: 150, null: false
      t.string :export_format, limit: 10, null: false
      t.string :file_name, limit: 255, null: false
      t.binary :content
      t.integer :invoice_count, default: 0, null: false
      t.bigint :replaces_report_id
      t.string :created_by, limit: 255, null: false
      t.datetime :expires_at, null: false
      t.datetime :purged_at
      t.timestamps
    end
    add_index 'aim.fiscal_reports', :agency_group_id, name: 'index_aim_fiscal_reports_on_group'
    add_index 'aim.fiscal_reports', :expires_at, name: 'index_aim_fiscal_reports_on_expires_at'

    create_table 'aim.fiscal_report_invoices' do |t|
      t.bigint :fiscal_report_id, null: false
      t.bigint :invoice_id, null: false
      t.timestamps
    end
    add_index 'aim.fiscal_report_invoices', %i[fiscal_report_id invoice_id], unique: true,
                                                                             name: 'index_aim_fiscal_report_invoices_on_pair'
    add_index 'aim.fiscal_report_invoices', :invoice_id, name: 'index_aim_fiscal_report_invoices_on_invoice'
  end
end
