# frozen_string_literal: true

require 'test_helper'

module Aim
  # The Users & Queues screen (item a.1): who works AIM, and how, in a list or
  # grouped by budget unit.
  class AdminControllerTest < ActionController::TestCase
    tests Aim::AdminController

    setup do
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
    end

    test 'lists the people added on the screen and those in the AIM groups' do
      added, grouped = two_employees
      as_groups 'aim_admin'
      Aim::Member.create!(employee_id: added.id)
      group = Group.create!(Group_Name: 'aim_staff')
      EmployeeGroup.create!(GroupID: group.GroupID, EmployeeID: grouped.id)

      get :index

      assert_response :success
      assert_includes response.body, added.last_name
      assert_includes response.body, grouped.last_name
      assert_includes response.body, 'In AIM through a group'
      assert_select 'th', text: /Role/
      assert_includes response.body, 'AIM Staff'
    end

    test 'the By BU view groups people under their unit, and the choice is remembered' do
      employee = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit')
      as_groups 'aim_admin'
      Aim::Member.create!(employee_id: employee.id)

      get :index, params: { view: 'bu' }

      assert_response :success
      assert_select '.aim-owner-group__name', text: /\A#{Regexp.escape(employee.unit)}/
      get :index
      assert_select '.aim-owner-group__name', minimum: 1
    end

    test 'filters to people with open invoices' do
      busy, idle = two_employees
      as_groups 'aim_admin'
      Aim::Member.create!(employee_id: busy.id)
      Aim::Member.create!(employee_id: idle.id)
      Aim::Invoice.create!(actor: 'test', batch_id: 'B-1', state: 'ready_for_approval', assigned_employee_id: busy.id)

      get :index, params: { has_open: '1', view: 'list' }

      assert_includes response.body, busy.last_name
      assert_not_includes response.body, ">#{idle.last_name}, "
    end

    test 'someone on the list GSABSS no longer knows is shown and flagged' do
      as_groups 'aim_admin'
      Aim::Member.create!(employee_id: 999_999_999)

      get :index, params: { view: 'list' }

      assert_includes response.body, 'Employee 999999999'
      assert_includes response.body, 'Not in GSABSS'
    end

    test 'AIM staff are sent away' do
      as_groups 'aim_staff'

      get :index

      assert_redirected_to aim_root_path
    end

    private

    def two_employees
      employees = Employee.order(:id).limit(2).to_a
      skip 'need two employees to test with' if employees.size < 2
      employees
    end

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
