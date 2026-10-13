# frozen_string_literal: true

require 'test_helper'

module Aim
  # Signs the test in with these ACL groups.
  module ReportTemplateSession
    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end

  # Fiscal report templates (#131): saved by a group's Fiscal, picked when
  # downloading; nobody reaches another group's.
  class ReportTemplatesControllerTest < ActionController::TestCase
    include ReportTemplateSession

    tests Aim::ReportTemplatesController

    setup do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      as_groups
      @gsa = Aim::AgencyGroup.for_agency!('GSA')
      @gsa.roles.create!(employee_id: 42, role: 'fiscal')
      @sheriff = Aim::AgencyGroup.for_agency!('SHF')
    end

    test 'Fiscal saves a template for their group, in their order and names' do
      post :create, params: { agency_group_id: @gsa.id, name: ' Payment upload ', export_format: 'tab',
                              export_columns: %w[Total Title], export_headers: { 'Total' => 'Amount' } }

      template = @gsa.report_templates.find_by!(name: 'Payment upload')
      assert_equal ['tab', %w[Total Title], 'Amount'], [template.export_format, template.export_column_list, template.export_header('Total')]
      assert_redirected_to aim_report_templates_path

      get :index
      assert_select 'a', text: 'Payment upload'
    end

    test 'not for another group, and another group\'s cannot be opened' do
      post :create, params: { agency_group_id: @sheriff.id, name: 'Theirs', export_columns: ['Title'] }
      assert_equal 0, Aim::ReportTemplate.count

      theirs = @sheriff.report_templates.create!(name: 'Theirs')
      get :edit, params: { id: theirs.id }
      assert_redirected_to aim_report_templates_path
    end

    test 'the new and edit pages draw, a copy starting from the layout copied' do
      source = @gsa.report_templates.create!(name: 'Source', export_column_list: %w[Total Title])
      get :new, params: { agency_group_id: @gsa.id, copy: source.id }

      assert_response :success
      assert_select 'ol.aim-column-order li:first-child input[checked][value=?]', 'Total'

      get :edit, params: { id: source.id }
      assert_response :success
      assert_select 'input[name=name][value=?]', 'Source'
    end

    test 'a template with no columns is not saved' do
      post :create, params: { agency_group_id: @gsa.id, name: 'Empty', export_columns: [] }

      assert_response :unprocessable_content
      assert_equal 0, Aim::ReportTemplate.count
    end
  end

  class FiscalExportTemplateTest < ActionController::TestCase
    include ReportTemplateSession

    tests Aim::FiscalExportsController

    test 'the template picked lays out the report, even for invoices of two groups' do
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
      gsa = Aim::AgencyGroup.for_agency!('GSA')
      template = gsa.report_templates.create!(name: 'Short', export_column_list: ['Invoice Number'])
      records = [['4641.T-1', 'GSA'], ['2500.T-2', 'SHF']].map do |batch, agency|
        invoice = Aim::Invoice.create!(batch_id: batch, state: 'exported', actor: 'test', invoice_number: batch,
                                       budget_unit: batch[0, 4], agency: agency)
        Aim::FiscalRecord.create!(invoice: invoice, status: 'ready')
      end

      post :create, params: { record_ids: records.map(&:id), report_template: "t#{template.id}" }

      assert_equal [['Invoice Number'], ['4641.T-1'], ['2500.T-2']].sort, CSV.parse(response.body).sort
    end
  end
end
