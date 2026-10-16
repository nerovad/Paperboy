# frozen_string_literal: true

require 'test_helper'

# AIM's lists are paged like Records (#101): each list page carries the page
# size for aim_queue_filter_controller and a pager under the list. The paging
# itself runs in the browser; this keeps every page wired to it.
class AimPagedListsTest < ActionDispatch::IntegrationTest
  PAGES = {
    'My Queue' => '/aim/my_queue',
    'Ready for Approval' => '/aim/invoices?queue=ready_for_approval',
    'Finished' => '/aim/invoices?queue=exported',
    'Fiscal Queue' => '/aim/fiscal?status=review',
    'Fiscal Reports' => '/aim/fiscal/reports',
    'Vendor Aliases' => '/aim/vendor_aliases',
    'Vendor Rules' => '/aim/vendor_rules',
    'Coding Rules' => '/aim/lookups',
    'Lookup Imports' => '/aim/lookups/imports',
    'Users & Queues' => '/aim/admin',
    'Shared Queues' => '/aim/shared_queues',
    'By BU' => '/aim/budget_units'
  }.freeze

  setup do
    employee = Employee.order(:id).first || skip('no employee')
    Aim::Member.create!(employee_id: employee.id)
    Aim::UserBudgetUnit.create!(employee_id: employee.id, budget_unit: '4641', shared_queue: true)
    Aim::VendorAlias.create!(extracted_name: 'ACME INC', normalized_name: 'Acme', learned_by: 'test')
    Aim::VendorRule.create!(vendor_name: 'Acme', rules: 'One rule', updated_by: 'test')
    Aim::CodingRule.create!(agency: 'GSA', budget_unit: '4641', vendor_name: 'ACME', encumbrance: 'BDO_46402024072600000001_1',
                            object_code: '2162', effective_from: Date.new(2024, 7, 1))
    %w[ready_for_approval exported].each_with_index do |state, i|
      Aim::Invoice.create!(batch_id: "4641.PL-#{i}", state: state, actor: 'test', budget_unit: '4641', agency: 'GSA',
                           document_type: 'Invoice', vendor_name: 'ACME', invoice_number: "PL-#{i}", assigned_employee_id: employee.id)
    end
    Aim::Invoice.create!(batch_id: '4641.PL-shared', state: 'ready_for_approval', actor: 'test', budget_unit: '4641',
                         agency: 'GSA', document_type: 'Invoice', vendor_name: 'ACME', invoice_number: 'PL-S')
    Aim::CodingImport.create!(agency: 'GSA', file_name: 'Fleet.csv', imported_by: 'test', effective_option: 'today',
                              status: 'previewed')
    Aim::FiscalRecord.create!(invoice: Aim::Invoice.find_by!(batch_id: '4641.PL-1'))
    Aim::FiscalReport.process!(Aim::FiscalExport.new(Aim::FiscalRecord.all), layout: nil, by: 'test')
    # An AIM Admin the way ACL makes one: in the aim_admin group.
    group = Group.find_or_create_by!(Group_Name: 'aim_admin')
    EmployeeGroup.create!(GroupID: group.GroupID, EmployeeID: employee.id)
    post '/login', params: { id: employee.employee_id }
  end

  PAGES.each do |name, path|
    test "#{name} is paged #{Pfa::Grid::Table::PAGE_ROWS} rows at a time with a pager under the list" do
      get path

      assert_response :success
      assert_select "[data-aim-queue-filter-page-size-value='#{Pfa::Grid::Table::PAGE_ROWS}']"
      assert_select '.aim-list-pager[data-aim-queue-filter-target=pager]'
    end
  end
end
