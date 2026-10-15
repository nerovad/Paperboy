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
      assert_select 'form[action=?][data-turbo-frame=aim-report-preview]', aim_fiscal_export_preview_path do
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

    test 'the Fiscal page saves what Fiscal types, the invoice\'s fields too, with a history line' do
      get :show, params: { id: @invoice.batch_id }
      assert_response :success
      assert_select 'button[name=fiscal_action][value=hold]', text: 'Hold'

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'save',
                               fiscal_record: { check_number: ' 1001 ', pay_doc_number: 'PD 1' },
                               coding_line: { encumbrance: 'bdo_46402024072600000009_1', object_code: '2162', fund: 'G001' },
                               invoice: { vendor_name: 'ACME Inc', invoice_number: 'A-1' } }

      record = Aim::FiscalRecord.find_by(invoice_id: @invoice.id)
      assert_equal %w[1001 review], [record.check_number, record.status]
      assert_equal 'fiscal@example.com', record.updated_by
      assert_equal 'ACME Inc', @invoice.reload.vendor_name
      line = @invoice.coding
      assert_equal ['BDO_46402024072600000009_1', '2162', 'fiscal', 'fiscal@example.com'],
                   [line.encumbrance, line.object_code, line.source, line.set_by]
      notes = @invoice.events.map(&:note)
      assert_includes notes, 'Fiscal changed Vendor Name'
      assert_includes notes, 'Fiscal set Encumbrance Number, Encumbrance Type, Fund, and Object'
    end

    test 'the PDF goes by Fiscal\'s name' do
      dir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(dir, @invoice.batch_id))
      File.write(File.join(dir, @invoice.batch_id, "#{@invoice.batch_id}.pdf"), '%PDF-1.4')
      Aim::InvoiceDirectoryService.instance.stub(:store_dir, dir) { get :pdf, params: { id: @invoice.batch_id } }

      assert_response :success
      assert_match(/filename="4641_ACME_A-1_\.pdf"/, response.headers['Content-Disposition'])
    end

    test 'the stamped copy is shown once it is there' do
      dir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(dir, @invoice.batch_id))
      File.write(File.join(dir, @invoice.batch_id, "#{@invoice.batch_id}.pdf"), '%PDF-1.4 received')
      File.write(File.join(dir, @invoice.batch_id, "#{@invoice.batch_id}.stamped.pdf"), '%PDF-1.4 stamped')
      Aim::InvoiceDirectoryService.instance.stub(:store_dir, dir) { get :pdf, params: { id: @invoice.batch_id } }

      assert_equal '%PDF-1.4 stamped', response.body
    end

    test 'Hold needs a reason, and a button label is no action' do
      patch :update, params: { id: @invoice.batch_id, commit: 'Hold', reason: 'Missing MA' }
      assert_equal 'Unknown action.', flash[:alert]
      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'hold' }
      assert_match(/Say why/, flash[:alert])

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'hold', reason: 'Missing MA' }

      record = Aim::FiscalRecord.find_by(invoice_id: @invoice.id)
      assert_equal ['on_hold', 'Missing MA'], [record.status, record.hold_reason]
    end

    test 'Release, Ready and Archive move it on; a move it cannot make is refused' do
      record = Aim::FiscalRecord.create!(invoice: @invoice, status: 'on_hold', hold_reason: 'x')

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'release' }
      assert_equal ['review', nil], [record.reload.status, record.hold_reason]

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'make_ready' }
      assert_equal 'ready', record.reload.status

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'archive' }
      assert_match(/cannot go to Archived/, flash[:alert])
      assert_equal 'ready', record.reload.status
    end

    test 'an archived invoice keeps what it had' do
      record = Aim::FiscalRecord.create!(invoice: @invoice, status: 'archived', check_number: '1')

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'save', fiscal_record: { check_number: '2' } }

      assert_equal '1', record.reload.check_number
    end

    test 'an invoice not yet approved is not Fiscal\'s' do
      Aim::Invoice.create!(batch_id: '4641.F-2', state: 'needs_review', actor: 'test')
      get :show, params: { id: '4641.F-2' }

      assert_redirected_to aim_fiscal_path
    end
  end

  # The Fiscal stage by agency group (#131): Fiscal sees its groups' invoices
  # and those its group also processes; each group's own archive rules.
  class FiscalAgencyGroupsTest < ActionController::TestCase
    include FiscalTestGroups

    tests Aim::FiscalController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
      @invoice = Aim::Invoice.create!(batch_id: '4641.F-1', state: 'approved', actor: 'test', budget_unit: '4641',
                                      vendor_name: 'ACME', invoice_number: 'A-1')
    end

    test 'Fiscal in an agency group gets in, and sees only that group\'s invoices' do
      as_groups
      gsa = Aim::AgencyGroup.for_agency!('GSA')
      gsa.roles.create!(employee_id: 42, role: 'fiscal')
      @invoice.update!(agency: 'GSA')
      Aim::Invoice.create!(batch_id: '2500.F-9', state: 'approved', actor: 'test', budget_unit: '2500', agency: 'SHF')
      get :index

      assert_response :success
      assert_equal [@invoice.id], @controller.instance_variable_get(:@records).map(&:invoice_id)

      get :show, params: { id: '2500.F-9' }
      assert_redirected_to aim_fiscal_path
    end

    test 'a group whose Fiscal also processes another sees both' do
      as_groups
      gsa = Aim::AgencyGroup.for_agency!('GSA')
      gsa.roles.create!(employee_id: 42, role: 'fiscal')
      sheriff = Aim::AgencyGroup.for_agency!('SHF')
      gsa.coverages.create!(covered_group: sheriff)
      @invoice.update!(agency: 'GSA')
      other = Aim::Invoice.create!(batch_id: '2500.F-9', state: 'approved', actor: 'test', budget_unit: '2500', agency: 'SHF')
      get :index

      assert_equal [@invoice.id, other.id].sort, @controller.instance_variable_get(:@records).map(&:invoice_id).sort
    end

    test 'straight to Fiscal: Report Queue waits for the details, and typing them in requests the export' do
      @invoice.update!(manual_entry: true, invoice_date: nil, invoice_total: nil, document_type: 'Invoice')
      Aim::FiscalRecord.create!(invoice: @invoice)

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'make_ready' }
      assert_match(/Type in the invoice's details first/, flash[:alert])

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'save',
                               invoice: { invoice_date: '2026-10-01', invoice_total: '12.50' } }
      @invoice.reload
      assert_equal [false, 'export'], [@invoice.manual_entry, @invoice.command]
    end

    test 'Archive waits for what the agency group needs' do
      @invoice.update!(agency: 'GSA')
      Aim::AgencyGroup.for_agency!('GSA').update!(required_field_list: %w[check_number])
      record = Aim::FiscalRecord.create!(invoice: @invoice, status: 'exported')

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'archive' }
      assert_match(/needs Check Number before archive/, flash[:alert])
      assert_equal 'exported', record.reload.status

      patch :update, params: { id: @invoice.batch_id, fiscal_action: 'archive', fiscal_record: { check_number: '501' } }
      assert_equal 'archived', record.reload.status
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

    test 'the preview changes nothing and offers both downloads' do
      post :preview, params: { record_ids: [@record.id] }

      assert_response :success
      assert_select 'turbo-frame#aim-report-preview table td', text: 'E-1'
      assert_select 'button[name=report_action][value=draft]'
      assert_select 'button[name=report_action][value=process]'
      assert_equal 'ready', @record.reload.status
      assert_equal 0, Aim::FiscalReport.count
    end

    test 'Download only gives a draft: nothing saved, nothing moved' do
      post :create, params: { record_ids: [@record.id], report_action: 'draft' }

      assert_response :success
      assert_equal 'text/csv', response.media_type
      assert_match(/attachment; filename="AIM_Fiscal_Report_DRAFT_\d+_\d+\.csv"/, response.headers['Content-Disposition'])
      assert_equal 2, CSV.parse(response.body).size
      assert_equal 'ready', @record.reload.status
      assert_equal 0, Aim::FiscalReport.count
    end

    test 'Download and process saves a numbered report, moves the invoice and names it in the history' do
      post :create, params: { record_ids: [@record.id], report_action: 'process' }

      report = Aim::FiscalReport.sole
      assert_redirected_to aim_fiscal_report_path(report, download: 1)
      assert_equal 'exported', @record.reload.status
      assert_not_nil @record.exported_at
      assert_equal [@record.invoice_id], report.invoices.pluck(:id)
      assert_equal "AIM_Fiscal_Report_#{format('%06d', report.id)}.csv", report.file_name
      assert_includes @record.invoice.events.pluck(:note).join("\n"), "In Fiscal report #{report.number}"
      assert_in_delta 1.year.from_now, report.expires_at, 1.minute
    end

    test 'nothing ticked is refused' do
      post :preview
      assert_select '.pb-modal__message', text: /Tick at least one/

      post :create, params: { report_action: 'process' }

      assert_match(/Tick at least one/, flash[:alert])
      assert_equal 'ready', @record.reload.status
    end

    test 'the report follows the agency group: its columns and its format' do
      @record.invoice.update!(agency: 'GSA')
      Aim::AgencyGroup.for_agency!('GSA').update!(export_format: 'tab', export_column_list: ['Invoice Number', 'Title'],
                                                  export_headers: { 'Invoice Number' => 'Inv #' })
      post :create, params: { record_ids: [@record.id], report_action: 'draft' }

      assert_match(/filename="AIM_Fiscal_Report_DRAFT_\d+_\d+\.txt"/, response.headers['Content-Disposition'])
      text = response.body.dup.force_encoding('UTF-16LE').encode('UTF-8').delete_prefix("\uFEFF")
      header, row = CSV.parse(text, col_sep: "\t")
      assert_equal ['Inv #', 'Title'], header, 'the group\'s order and names'
      assert_equal 'E-1', row.first
    end

    test 'invoices of two groups with different reports are not mixed' do
      @record.invoice.update!(agency: 'GSA')
      other = Aim::Invoice.create!(batch_id: '2500.E-2', state: 'exported', actor: 'test', budget_unit: '2500', agency: 'SHF')
      second = Aim::FiscalRecord.create!(invoice: other, status: 'ready')
      post :create, params: { record_ids: [@record.id, second.id], report_action: 'process' }

      assert_match(/different reports/, flash[:alert])
      assert_equal 'ready', @record.reload.status
    end

    test 'an invoice still in the Fiscal Queue is not exported' do
      @record.update!(status: 'review')
      post :create, params: { record_ids: [@record.id], report_action: 'process' }

      assert_match(/Tick at least one/, flash[:alert])
    end
  end
end
