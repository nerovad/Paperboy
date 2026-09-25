# frozen_string_literal: true

require 'test_helper'

module Aim
  # A person's budget units and BU Admin flags, set on their profile (a.2).
  class MemberBudgetUnitsControllerTest < ActionController::TestCase
    tests Aim::MemberBudgetUnitsController

    setup do
      @employee = Employee.where.not(unit: [nil, '']).order(:id).first
      skip 'no employee with a unit to test with' if @employee.nil?
      Aim::Member.create!(employee_id: @employee.id)
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
    end

    test 'adds a budget unit, as BU Admin when asked' do
      post :create, params: { member_id: @employee.id, budget_unit: '9999', bu_admin: '1' }

      assert_redirected_to aim_member_path(@employee.id, anchor: 'roles')
      row = Aim::UserBudgetUnit.find_by(employee_id: @employee.id, budget_unit: '9999')
      assert row.bu_admin
      assert_equal 'aim.admin@example.com', row.granted_by
      assert_includes Aim::Users.shared_budget_units(@employee.id, staff: false), '9999'
      assert_equal ['9999'], Aim::Users.administered_budget_units(@employee.id)
    end

    test 'the home unit counts without a row, and a row for it only carries BU Admin' do
      assert_equal [@employee.unit], Aim::Users.shared_budget_units(@employee.id, staff: false)

      post :create, params: { member_id: @employee.id, budget_unit: @employee.unit, bu_admin: '1' }
      row = Aim::UserBudgetUnit.find_by!(employee_id: @employee.id, budget_unit: @employee.unit)
      patch :update, params: { member_id: @employee.id, id: row.id, bu_admin: '0' }

      assert_nil Aim::UserBudgetUnit.find_by(id: row.id), 'clearing BU Admin on the home unit drops its row'
      assert_equal [@employee.unit], Aim::Users.shared_budget_units(@employee.id, staff: false)
    end

    test 'toggles BU Admin on an added unit and takes it away' do
      row = Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '9999')

      patch :update, params: { member_id: @employee.id, id: row.id, bu_admin: '1' }
      assert row.reload.bu_admin

      delete :destroy, params: { member_id: @employee.id, id: row.id }
      assert_nil Aim::UserBudgetUnit.find_by(id: row.id)
    end

    test 'AIM staff do not change budget units' do
      as_groups 'aim_staff'

      post :create, params: { member_id: @employee.id, budget_unit: '9999' }

      assert_redirected_to aim_root_path
      assert_equal 0, Aim::UserBudgetUnit.count
    end

    test 'roles name AIM Admin, AIM Staff and BU Admin, or User' do
      assert_equal ['User'], Aim::Users.roles_of(@employee.id)

      Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '9999', bu_admin: true)
      staff = Group.create!(Group_Name: 'aim_staff')
      EmployeeGroup.create!(GroupID: staff.GroupID, EmployeeID: @employee.id)

      assert_equal ['AIM Staff', 'BU Admin'], Aim::Users.roles_of(@employee.id)
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
