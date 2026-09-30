# frozen_string_literal: true

require 'test_helper'

module Aim
  # What a person changes on the review page and the Fiscal page is in the
  # edit trail (RecordEdit), from what to what, under their name.
  class ReviewEditTrailTest < ActionController::TestCase
    tests Aim::InvoicesController

    setup do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42, 'first_name' => 'Aim',
                         'last_name' => 'Staff' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    test 'the review page\'s edits are audited under the reviewer' do
      row = Aim::Invoice.create!(batch_id: '4601.ET1', state: 'needs_review', actor: 'aim_worker', document_type: 'Invoice',
                                 vendor_name: 'ACME', budget_unit: '4601')

      patch :update, params: { id: row.batch_id, queue: 'needs_review', invoice_action: 'save',
                               invoice: { vendor_name: 'ACME Supply', invoice_number: 'INV-9' } }

      edits = RecordEdit.for_row(row).pluck(:column_name, :old_value, :new_value, :changed_by_id, :changed_by_name)
      assert_includes edits, ['vendor_name', 'ACME', 'ACME Supply', '42', 'Aim Staff']
      assert_includes edits, ['invoice_number', nil, 'INV-9', '42', 'Aim Staff']
    end
  end

  class FiscalEditTrailTest < ActionController::TestCase
    tests Aim::FiscalController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42, 'first_name' => 'Fi', 'last_name' => 'Scal' }
      @controller.define_singleton_method(:current_user_group_names) { Set['aim_admin'] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
      @invoice = Aim::Invoice.create!(batch_id: '4641.ET2', state: 'approved', actor: 'test', budget_unit: '4641',
                                      vendor_name: 'ACME', invoice_number: 'A-1')
    end

    test 'Fiscal\'s corrections, its own fields and the coding are all in the trail' do
      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'save', fiscal_record: { check_number: '1001' },
                               coding_line: { fund: 'G001' }, invoice: { vendor_name: 'ACME Inc' } }

      record = Aim::FiscalRecord.find_by!(invoice_id: @invoice.id)
      line = @invoice.reload.coding
      assert_equal [%w[vendor_name ACME], ['ACME Inc', '42']],
                   RecordEdit.for_row(@invoice).where(column_name: 'vendor_name')
                             .pluck(:column_name, :old_value, :new_value, :changed_by_id).first.each_slice(2).to_a
      assert RecordEdit.for_row(record).exists?(column_name: 'check_number', new_value: '1001', changed_by_name: 'Fi Scal')
      assert RecordEdit.for_row(line).exists?(action: 'create', column_name: 'fund', new_value: 'G001')
      assert_includes @invoice.events.map(&:note), 'Fiscal changed Vendor Name'
    end
  end
end
