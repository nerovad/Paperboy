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
      @invoice.coding_lines.create!(encumbrance: 'BDO_46402024072600000009_1', object_code: '2162', activity: 'GATV',
                                    source: 'fiscal')
    end

    test 'the report has Fiscal\'s header exactly, and one row per invoice' do
      rows = CSV.parse(Aim::FiscalExport.new([@record]).to_csv)

      assert_equal 30, rows.first.size
      assert_equal %w[Unit Object], rows.first[18, 2]
      assert_equal 'Handle', rows.first[27]
      assert_equal 2, rows.size
      row = Aim::FiscalExport::COLUMNS.zip(rows.last).to_h
      assert_equal '4641_ACME "West"_A-9_20260903', row['Title']
      assert_equal '20260903', row['Invoice Date AP']
      assert_equal '12.50', row['Total']
      assert_equal '1.00', row['Sales Tax']
      assert_equal "AIM-#{@invoice.id}", row['Handle']
      assert_equal '1001', row['Check Number']
      assert_equal %w[BDO_46402024072600000009_1 2162 GATV], row.values_at('BDO / DO', 'Object', 'Activity')
      assert_nil row['Split Invoice Amount']
      assert_match(%r{\Anobody@example.com_\d{2}/\d{2}/\d{4}_\d{2}:\d{2}:\d{2}\z}, row['Description'])
    end

    test 'Fiscal\'s description follows the approval stamp, and tags are the keywords' do
      @record.update!(description: 'PRUDENTIALOVFY25MA01', tags: 'HOLD PMT, emailed Karen')
      row = Aim::FiscalExport::COLUMNS.zip(Aim::FiscalExport.new([@record.reload]).rows.first).to_h

      assert_match(/_\d{2}:\d{2}:\d{2} _ PRUDENTIALOVFY25MA01\z/, row['Description'])
      assert_equal 'HOLD PMT, emailed Karen', row['Keywords']
    end

    test 'text cells are defused against formulas; money, credits included, is left for the macro' do
      @invoice.update!(vendor_name: '=HYPERLINK("x")')
      @record.update!(credit_amount: -25, description: '+1 call Karen')
      row = Aim::FiscalExport::COLUMNS.zip(Aim::FiscalExport.new([@record.reload]).rows.first).to_h

      assert_equal %('=HYPERLINK("x")), row['Vendor Name']
      assert row['Title'].start_with?('4641_=HYPERLINK')
      assert_equal '-25.00', row['Credit Amount']
      assert_equal '12.50', row['Total']
      assert_match(/ _ \+1 call Karen\z/, row['Description'])
    end
  end
end
