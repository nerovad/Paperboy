# frozen_string_literal: true

# PDF versions (#182): every swap, edit and restore of an invoice's PDF is a
# row -- the base PDF it starts from and any inserted PDFs (files beside the
# invoice in the store), and the edit plan the editor sent (pages, turns,
# crops, text boxes), or none for the base as it is. <batch id>.pdf is the
# current row rendered, so the editor can always reopen the plan and its text
# boxes stay editable until Fiscal archives the invoice.
#
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb. A second run, or a run after a
# crash, creates only what is missing.
class CreateAimPdfVersions < ActiveRecord::Migration[8.1]
  def up
    unless table_exists?('aim.pdf_versions')
      create_table 'aim.pdf_versions' do |t|
        t.bigint :invoice_id, null: false
        t.integer :number, null: false
        t.string :kind, limit: 20, null: false
        t.string :base_file, limit: 300, null: false
        t.text :inserts
        t.text :plan
        t.string :note, limit: 1000
        t.string :created_by, limit: 255, null: false
        t.datetime :created_at, null: false
      end
    end
    add_index 'aim.pdf_versions', %i[invoice_id number], unique: true, name: 'index_aim_pdf_versions_on_invoice_and_number',
                                                         if_not_exists: true
  end

  def down
    drop_table 'aim.pdf_versions', if_exists: true
  end
end
