# frozen_string_literal: true

require 'test_helper'

module Aim
  # AIM's invoices, Fiscal records and coding lines keep Paperboy's edit trail
  # (AuditableEdits through Aim::Audited): a RecordEdit per changed column,
  # but none for the lock, the worker's lease or bookkeeping stamps.
  class AuditTest < ActiveSupport::TestCase
    USER = { 'employee_id' => 42, 'email' => 'jane@example.com', 'first_name' => 'Jane', 'last_name' => 'Doe' }.freeze

    setup { Current.user = USER }
    teardown { Current.reset }

    def invoice(**attributes)
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: 'approved', actor: 'aim_worker',
                           document_type: 'Invoice', budget_unit: '4601', vendor_name: 'ACME', **attributes)
    end

    def trail(row) = RecordEdit.for_row(row).order(:id).pluck(:column_name, :old_value, :new_value, :changed_by_name)

    test 'a reviewer\'s edit to an invoice is in its trail, from what to what and by whom' do
      row = invoice

      row.update!(vendor_name: 'ACME Supply', invoice_total: 12.5)

      assert_equal([['vendor_name', 'ACME', 'ACME Supply', 'Jane Doe'], ['invoice_total', nil, '12.5', 'Jane Doe']],
                   trail(row).sort_by { |column, *| column == 'vendor_name' ? 0 : 1 })
      assert_equal ['aim.invoices'], RecordEdit.for_row(row).distinct.pluck(:table_slug)
      assert_equal [row], [row.edit_timeline.first.record]
    end

    test 'the lock, the worker\'s lease and command and the coding stamp leave no trail' do
      row = invoice

      row.update!(claimed_by: 'x@example.com', claimed_at: Time.current, lease_owner: 'w1', lease_until: 1.minute.from_now,
                  command: 'export', coded_at: Time.current, attempt: 2)

      assert_empty trail(row)
    end

    test 'with nobody signed in, an edit is credited to the actor the invoice was given, else AIM' do
      Current.user = nil
      row = invoice

      row.update!(vendor_name: 'By a job')
      row.transition_to!('needs_review', actor: 'worker@example.com', notes: 'sent back')

      assert_equal 'aim', RecordEdit.for_row(row).find_by(column_name: 'vendor_name').changed_by_name
      assert_equal 'worker@example.com', RecordEdit.for_row(row).find_by(column_name: 'notes').changed_by_name
    end

    test 'Fiscal\'s edits are audited, and a move of status stays in the invoice\'s history' do
      row = invoice
      record = Aim::FiscalRecord.create!(invoice: row)

      record.update!(check_number: '1001', updated_by: 'fiscal@example.com')
      record.move_to!('ready', actor: 'fiscal@example.com')

      assert_equal [['check_number', nil, '1001', 'Jane Doe']], trail(record)
      assert_match(/Fiscal Queue → Report Queue/, row.events.last.note)
    end

    test 'a coding line\'s whole life is kept, so deleting it keeps who had coded the invoice' do
      row = invoice
      line = row.coding_lines.create!(line_no: 1, source: 'person', fund: 'G001', set_by: 'jane@example.com')
      line.update!(fund: 'G002')
      line_id = line.id

      row.coding_lines.destroy_all

      actions = RecordEdit.where(record_type: 'Aim::CodingLine', record_id: line_id, column_name: 'fund')
                          .order(:id).pluck(:action, :old_value, :new_value)
      assert_equal [['create', nil, 'G001'], %w[update G001 G002], ['destroy', 'G002', nil]], actions
      assert_not RecordEdit.exists?(record_type: 'Aim::CodingLine', record_id: line_id, column_name: 'set_by')
    end

    test 'invoices, Fiscal records and coding lines are all audited models' do
      assert_includes Aim::Invoice, AuditableEdits
      assert_includes Aim::FiscalRecord, AuditableEdits
      assert_includes Aim::CodingLine, AuditableEdits
    end
  end
end
