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
      group = Group.create!(Group_Name: 'aim_admin')
      EmployeeGroup.create!(GroupID: group.GroupID, EmployeeID: grouped.id)

      get :index

      assert_response :success
      assert_includes response.body, added.last_name
      assert_includes response.body, grouped.last_name
      assert_includes response.body, 'AIM Admin through the aim_admin group'
      assert_select 'th', text: /Role/
      assert_includes response.body, 'AIM Admin'
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

    test 'filters by agency, read from the COA' do
      employee = Employee.where('agency LIKE ?', 'GSA%').order(:id).first || skip('no GSA employee')
      as_groups 'aim_admin'
      Aim::Member.create!(employee_id: employee.id)

      get :index, params: { view: 'list', agency: 'GSA' }
      assert_includes response.body, employee.last_name
      assert_select 'select[name=agency] option[value=GSA]'

      get :index, params: { view: 'list', agency: 'SHF' }
      assert_not_includes response.body, ">#{employee.last_name}, "
    end

    test 'inactive people are hidden unless asked for' do
      employee = Employee.order(:id).first || skip('no employee to test with')
      as_groups 'aim_admin'
      Aim::Member.create!(employee_id: employee.id, deactivated_at: Time.current)

      get :index, params: { view: 'list' }
      assert_not_includes response.body, ">#{employee.last_name}, "

      get :index, params: { view: 'list', inactive: '1' }
      assert_includes response.body, 'Inactive'
    end

    test 'someone who is not an AIM Admin is sent away' do
      as_groups

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
