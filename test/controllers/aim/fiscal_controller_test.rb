# frozen_string_literal: true

require 'test_helper'

module Aim
  # Signs the test in with these ACL groups, as the other AIM tests do.
  module FiscalTestGroups
    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end

  # The Fiscal stage (item f): Fiscal staff and AIM admins only; each button a
  # move of the Fiscal record.
  class FiscalControllerTest < ActionController::TestCase
    include FiscalTestGroups

    tests Aim::FiscalController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
      @invoice = Aim::Invoice.create!(batch_id: '4641.F-1', state: 'approved', actor: 'test', budget_unit: '4641',
                                      vendor_name: 'ACME', invoice_number: 'A-1')
    end

    test 'approved invoices appear in the Fiscal Queue on their own' do
      get :index

      assert_response :success
      assert_equal [@invoice.id], @controller.instance_variable_get(:@records).map(&:invoice_id)
      assert_select 'a[href=?]', aim_fiscal_invoice_path(@invoice.batch_id)
    end

    test 'the Report Queue ticks invoices for the report, all at once or by BU' do
      record = Aim::FiscalRecord.create!(invoice: @invoice, status: 'ready')
      get :index, params: { status: 'ready' }

      assert_response :success
      assert_select 'form[action=?]', aim_fiscal_export_path do
        assert_select 'input[type=checkbox][name=?][value=?]', 'record_ids[]', record.id.to_s
        assert_select 'input[data-select-all-target=selectAll]'
      end

      get :index, params: { status: 'ready', view: 'bu' }
      assert_select 'section.aim-bu-group input[name=?]', 'record_ids[]'
    end

    test 'someone who is neither Fiscal nor an AIM admin is turned away' do
      as_groups
      get :index

      assert_redirected_to aim_root_path
    end

    test 'a person marked Fiscal gets in' do
      as_groups
      Aim::Member.create!(employee_id: 42, fiscal: true)
      get :index

      assert_response :success
    end

    test 'the Fiscal page saves what Fiscal types, the invoice\'s fields too, with a history line' do
      get :show, params: { id: @invoice.batch_id }
      assert_response :success

      patch :update, params: { id: @invoice.batch_id, commit: 'Save',
                               fiscal_record: { check_number: ' 1001 ', pay_doc_number: 'PD 1', org_number: '12' },
                               invoice: { vendor_name: 'ACME Inc', invoice_number: 'A-1' } }

      record = Aim::FiscalRecord.find_by(invoice_id: @invoice.id)
      assert_equal %w[1001 12 review], [record.check_number, record.org_number, record.status]
      assert_equal 'fiscal@example.com', record.updated_by
      assert_equal 'ACME Inc', @invoice.reload.vendor_name
      assert_equal 'Fiscal changed Vendor Name', @invoice.events.last.note
    end

    test 'the PDF goes by Fiscal\'s name' do
      dir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(dir, @invoice.batch_id))
      File.write(File.join(dir, @invoice.batch_id, "#{@invoice.batch_id}.pdf"), '%PDF-1.4')
      Aim::InvoiceDirectoryService.instance.stub(:store_dir, dir) { get :pdf, params: { id: @invoice.batch_id } }

      assert_response :success
      assert_match(/filename="4641_ACME_A-1_\.pdf"/, response.headers['Content-Disposition'])
    end

    test 'Hold needs a reason' do
      patch :update, params: { id: @invoice.batch_id, commit: 'Hold' }
      assert_match(/Say why/, flash[:alert])

      patch :update, params: { id: @invoice.batch_id, commit: 'Hold', reason: 'Missing MA' }

      record = Aim::FiscalRecord.find_by(invoice_id: @invoice.id)
      assert_equal ['on_hold', 'Missing MA'], [record.status, record.hold_reason]
    end

    test 'Release, Ready and Archive move it on; a move it cannot make is refused' do
      record = Aim::FiscalRecord.create!(invoice: @invoice, status: 'on_hold', hold_reason: 'x')

      patch :update, params: { id: @invoice.batch_id, commit: 'Release' }
      assert_equal ['review', nil], [record.reload.status, record.hold_reason]

      patch :update, params: { id: @invoice.batch_id, commit: 'Add to Report Queue' }
      assert_equal 'ready', record.reload.status

      patch :update, params: { id: @invoice.batch_id, commit: 'Archive' }
      assert_match(/cannot go to Archived/, flash[:alert])
      assert_equal 'ready', record.reload.status
    end

    test 'an archived invoice keeps what it had' do
      record = Aim::FiscalRecord.create!(invoice: @invoice, status: 'archived', check_number: '1')

      patch :update, params: { id: @invoice.batch_id, commit: 'Save', fiscal_record: { check_number: '2' } }

      assert_equal '1', record.reload.check_number
    end

    test 'an invoice not yet approved is not Fiscal\'s' do
      Aim::Invoice.create!(batch_id: '4641.F-2', state: 'needs_review', actor: 'test')
      get :show, params: { id: '4641.F-2' }

      assert_redirected_to aim_fiscal_path
    end
  end

  # The export: ticked invoices, one file, and the ready ones become exported.
  class FiscalExportsControllerTest < ActionController::TestCase
    include FiscalTestGroups

    tests Aim::FiscalExportsController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
      invoice = Aim::Invoice.create!(batch_id: '4641.E-1', state: 'exported', actor: 'test', invoice_number: 'E-1')
      @record = Aim::FiscalRecord.create!(invoice: invoice, status: 'ready')
    end

    test 'exporting downloads the file and marks the ready ones exported' do
      post :create, params: { record_ids: [@record.id] }

      assert_response :success
      assert_equal 'text/csv', response.media_type
      assert_match(/attachment; filename="AIM_Fiscal_Report_\d+_\d+\.csv"/, response.headers['Content-Disposition'])
      assert_equal 2, CSV.parse(response.body).size
      assert_equal 'exported', @record.reload.status
      assert_not_nil @record.exported_at
    end

    test 'nothing ticked is refused' do
      post :create

      assert_match(/Tick at least one/, flash[:alert])
      assert_equal 'ready', @record.reload.status
    end

    test 'an invoice still in the Fiscal Queue is not exported' do
      @record.update!(status: 'review')
      post :create, params: { record_ids: [@record.id] }

      assert_match(/Tick at least one/, flash[:alert])
    end
  end

  # The Fiscal switch on a profile: AIM admins only.
  class MemberFiscalControllerTest < ActionController::TestCase
    include FiscalTestGroups

    tests Aim::MemberFiscalController

    setup do
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 1 }
      @member = Aim::Member.create!(employee_id: 77)
    end

    test 'an AIM admin switches Fiscal on and off' do
      as_groups 'aim_admin'
      patch :update, params: { id: 77, fiscal: '1' }
      assert @member.reload.fiscal

      patch :update, params: { id: 77, fiscal: '0' }
      assert_not @member.reload.fiscal
    end

    test 'nobody else can' do
      as_groups
      patch :update, params: { id: 77, fiscal: '1' }

      assert_not @member.reload.fiscal
    end
  end
end
