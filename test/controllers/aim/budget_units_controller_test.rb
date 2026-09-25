# frozen_string_literal: true

require 'test_helper'

module Aim
  # The BU page (item a.2): My BUs for a BU Admin, By BU for Staff and Admins.
  class BudgetUnitsControllerTest < ActionController::TestCase
    tests Aim::BudgetUnitsController

    setup do
      @employee = Employee.where.not(unit: [nil, '']).order(:id).first
      skip 'no employee with a unit to test with' if @employee.nil?
      session[:user] = { 'email' => 'bu.admin@example.com', 'employee_id' => 7 }
      as_groups
    end

    test "a BU Admin sees their BU's shared queue and people, and nothing of other BUs" do
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4703', bu_admin: true)
      Aim::Member.create!(employee_id: @employee.id)
      Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '4703')
      invoice('B-SH', budget_unit: '4703', invoice_number: 'INV-SHARED')
      invoice('B-PE', budget_unit: '4703', invoice_number: 'INV-PERSON', assigned_employee_id: @employee.id,
                      assigned_to: 'Someone', assignment_source: 'folder')
      invoice('B-XX', budget_unit: '4601', invoice_number: 'INV-ELSEWHERE')

      get :index

      assert_response :success
      assert_select 'h1', 'My BUs'
      assert_includes response.body, '4703 shared queue'
      assert_includes response.body, @employee.last_name
      assert_includes response.body, 'INV-SHARED'
      assert_includes response.body, 'INV-PERSON'
      assert_not_includes response.body, 'INV-ELSEWHERE'
    end

    test 'Staff see every BU, as By BU' do
      as_groups 'aim_staff'
      invoice('B-XX', budget_unit: '4601', invoice_number: 'INV-ELSEWHERE')

      get :index

      assert_select 'h1', 'By BU'
      assert_includes response.body, 'INV-ELSEWHERE'
    end

    test 'someone who is no BU Admin is sent away, and so is Staff in Approver mode' do
      get :index
      assert_redirected_to aim_root_path

      as_groups 'aim_staff'
      session[:aim_mode] = 'approver'
      get :index
      assert_redirected_to aim_root_path
    end

    private

    def invoice(batch_id, **attributes)
      Aim::Invoice.create!(batch_id: batch_id, state: 'ready_for_approval', actor: 'test', document_type: 'Invoice',
                           vendor_name: 'ACME', **attributes)
    end

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
