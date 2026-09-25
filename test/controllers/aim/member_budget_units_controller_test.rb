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
      assert_equal [@employee.unit], Aim::Users.budget_units_of(@employee.id)

      post :create, params: { member_id: @employee.id, budget_unit: @employee.unit, bu_admin: '1' }
      row = Aim::UserBudgetUnit.find_by!(employee_id: @employee.id, budget_unit: @employee.unit)
      patch :update, params: { member_id: @employee.id, id: row.id, bu_admin: '0' }

      assert_nil Aim::UserBudgetUnit.find_by(id: row.id), 'clearing BU Admin on the home unit drops its row'
      assert_equal [@employee.unit], Aim::Users.budget_units_of(@employee.id)
    end

    test 'hiding the home unit takes it out of their BUs, and showing it brings it back' do
      post :create, params: { member_id: @employee.id, budget_unit: @employee.unit, bu_admin: '1' }
      row = Aim::UserBudgetUnit.find_by!(employee_id: @employee.id, budget_unit: @employee.unit)

      patch :update, params: { member_id: @employee.id, id: row.id, hidden: '1' }
      assert row.reload.hidden
      assert_not row.bu_admin, 'hiding clears BU Admin'
      assert_empty Aim::Users.budget_units_of(@employee.id)

      patch :update, params: { member_id: @employee.id, id: row.id, hidden: '0' }
      assert_nil Aim::UserBudgetUnit.find_by(id: row.id)
      assert_equal [@employee.unit], Aim::Users.budget_units_of(@employee.id)
    end

    test 'only a home unit can be hidden' do
      row = Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '9999')

      patch :update, params: { member_id: @employee.id, id: row.id, hidden: '1' }

      assert_not row.reload.hidden
    end

    test "a BU's shared queue is off until switched on, BU Admins always have it, and a BU Admin switches it for their BUs" do
      assert_empty Aim::Users.shared_budget_units(@employee.id, staff: false), 'off by default, home unit too'

      post :create, params: { member_id: @employee.id, budget_unit: @employee.unit, shared_queue: '1' }
      assert_equal [@employee.unit], Aim::Users.shared_budget_units(@employee.id, staff: false)

      as_groups
      session[:user] = session[:user].merge('employee_id' => 7)
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4703', bu_admin: true)
      assert_equal ['4703'], Aim::Users.shared_budget_units(7, staff: false), 'a BU Admin always has it'
      theirs = Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '4703')
      home = Aim::UserBudgetUnit.find_by!(employee_id: @employee.id, budget_unit: @employee.unit)

      patch :update, params: { member_id: @employee.id, id: theirs.id, shared_queue: '1' }
      assert theirs.reload.shared_queue

      patch :update, params: { member_id: @employee.id, id: home.id, shared_queue: '0' }
      assert home.reload.shared_queue, 'not their BU to change' unless @employee.unit == '4703'
    end

    test 'toggles BU Admin on an added unit and takes it away' do
      row = Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '9999')

      patch :update, params: { member_id: @employee.id, id: row.id, bu_admin: '1' }
      assert row.reload.bu_admin

      delete :destroy, params: { member_id: @employee.id, id: row.id }
      assert_nil Aim::UserBudgetUnit.find_by(id: row.id)
    end

    test 'someone who is not an AIM Admin or BU Admin does not change budget units' do
      as_groups

      post :create, params: { member_id: @employee.id, budget_unit: '9999' }

      assert_redirected_to aim_root_path
      assert_equal 0, Aim::UserBudgetUnit.count
    end

    test 'a BU Admin adds and takes away only their own BUs, and appoints no BU Admins' do
      as_groups
      session[:user] = session[:user].merge('employee_id' => 7)
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4703', bu_admin: true)

      post :create, params: { member_id: @employee.id, budget_unit: '4703', bu_admin: '1' }
      row = Aim::UserBudgetUnit.find_by!(employee_id: @employee.id, budget_unit: '4703')
      assert_not row.bu_admin

      post :create, params: { member_id: @employee.id, budget_unit: '4601' }
      assert_nil Aim::UserBudgetUnit.find_by(employee_id: @employee.id, budget_unit: '4601')

      patch :update, params: { member_id: @employee.id, id: row.id, bu_admin: '1' }
      assert_not row.reload.bu_admin

      delete :destroy, params: { member_id: @employee.id, id: row.id }
      assert_nil Aim::UserBudgetUnit.find_by(id: row.id)
    end

    test 'roles name AIM Admin and BU Admin, or User' do
      assert_equal ['User'], Aim::Users.roles_of(@employee.id)

      Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '9999', bu_admin: true)
      admins = Group.create!(Group_Name: 'aim_admin')
      EmployeeGroup.create!(GroupID: admins.GroupID, EmployeeID: @employee.id)

      assert_equal ['AIM Admin', 'BU Admin'], Aim::Users.roles_of(@employee.id)
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
