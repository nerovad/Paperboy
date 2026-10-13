# frozen_string_literal: true

require 'test_helper'

module Aim
  # Saved Fiscal reports (#131): download again, regenerate, purge a year on,
  # and nobody opens another group's.
  class FiscalReportsControllerTest < ActionController::TestCase
    tests Aim::FiscalReportsController

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
      @gsa = Aim::AgencyGroup.for_agency!('GSA')
      invoice = Aim::Invoice.create!(batch_id: '4641.R-1', state: 'exported', actor: 'test', invoice_number: 'R-1',
                                     budget_unit: '4641', agency: 'GSA')
      @record = Aim::FiscalRecord.create!(invoice: invoice, status: 'ready')
      @report = Aim::FiscalReport.process!(Aim::FiscalExport.new([@record], group: @gsa), layout: @gsa, by: 'fiscal@example.com')
    end

    test 'lists reports and downloads one again exactly as it was made' do
      get :index
      assert_select 'a', text: @report.number

      get :download, params: { id: @report.id }
      assert_equal @report.content, response.body.b
      assert_match(/filename="#{@report.file_name}"/, response.headers['Content-Disposition'])
    end

    test 'straight after processing the report page downloads itself' do
      get :show, params: { id: @report.id, download: 1 }

      assert_select 'iframe[src=?]', download_aim_fiscal_report_path(@report)
      assert_select 'td a', text: '4641.R-1'
    end

    test 'regenerating makes a new numbered report of the same invoices, naming the one it replaces' do
      post :regenerate, params: { id: @report.id }

      fresh = Aim::FiscalReport.where.not(id: @report.id).sole
      assert_redirected_to aim_fiscal_report_path(fresh, download: 1)
      assert_equal @report, fresh.replaces
      assert_equal [@record.invoice_id], fresh.invoices.pluck(:id)
      assert_includes @record.invoice.events.pluck(:note).join("\n"), "replacing #{@report.number}"
    end

    test 'a year on the file is purged; the report and its invoices stay' do
      @report.update!(expires_at: 1.minute.ago)
      Aim::PurgeFiscalReportsJob.perform_now

      @report.reload
      assert @report.purged?
      assert_nil @report.content
      assert_equal 1, @report.report_invoices.count

      get :download, params: { id: @report.id }
      assert_redirected_to aim_fiscal_report_path(@report)
    end

    test 'Fiscal of another group cannot open it' do
      as_groups
      Aim::AgencyGroup.for_agency!('SHF').roles.create!(employee_id: 42, role: 'fiscal')

      get :show, params: { id: @report.id }
      assert_redirected_to aim_fiscal_reports_path
    end
  end
end
