# frozen_string_literal: true

require 'test_helper'

module Aim
  # Fiscal's bulk export: the header and one row per invoice, DocuShare's way
  # or as plain CSV.
  class FiscalExportTest < ActiveSupport::TestCase
    setup do
      @invoice = Aim::Invoice.create!(batch_id: '4641.X-1', state: 'approved', actor: 'nobody@example.com',
                                      budget_unit: '4641', vendor_name: 'ACME "West"', invoice_number: 'A-9',
                                      invoice_date: Date.new(2026, 9, 3), invoice_total: 12.5, sales_tax: 1)
      @record = Aim::FiscalRecord.create!(invoice: @invoice, check_number: '1001', pay_doc_number: 'PD 1')
    end

    test 'the CSV has DocuShare\'s columns in order and one row per invoice' do
      rows = CSV.parse(Aim::FiscalExport.new([@record]).to_csv)

      assert_equal Aim::FiscalExport::COLUMNS, rows.first
      assert_equal 2, rows.size
      row = Aim::FiscalExport::COLUMNS.zip(rows.last).to_h
      assert_equal '#INV_4641_ACME "West"_A-9_20260903', row['Title']
      assert_equal '20260903', row['Invoice Date AP']
      assert_equal '12.50', row['Total']
      assert_equal '1.00', row['Sales Tax']
      assert_equal '4641.X-1', row['Handle']
      assert_equal '1001', row['Check Number']
      assert_match(%r{\Anobody@example.com_\d{2}/\d{2}/\d{4}_\d{2}:\d{2}:\d{2}\z}, row['Description'])
    end

    test 'DocuShare\'s format is UTF-16 with a BOM, tab-separated, every value quoted' do
      text = Aim::FiscalExport.new([@record]).to_docushare

      assert_equal Encoding::UTF_16LE, text.encoding
      assert_equal Aim::FiscalExport::BOM.encode('UTF-16LE'), text[0]
      lines = text.encode('UTF-8').delete_prefix(Aim::FiscalExport::BOM).split("\r\n")
      assert_equal 2, lines.size
      assert lines.first.start_with?(%("Title"\t"Invoice Number"\t))
      assert_includes lines.last, %("ACME ""West""")
      assert_includes lines.last, %(\t""\t)
    end

    test 'the description is what Fiscal typed, else the hold reason while held' do
      @record.update!(status: 'on_hold', hold_reason: 'Missing MA')
      assert_equal 'Missing MA', description

      @record.update!(description: 'Paid by P-card')
      assert_equal 'Paid by P-card', description
    end

    private

    def description
      row = Aim::FiscalExport.new([@record.reload]).rows.first
      row[Aim::FiscalExport::COLUMNS.index('Description')]
    end
  end
end
