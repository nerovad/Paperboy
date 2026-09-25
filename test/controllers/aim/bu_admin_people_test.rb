# frozen_string_literal: true

require 'test_helper'

module Aim
  # A BU Admin manages people in their own BUs (item a.2): adds them with one
  # of those BUs, opens their profiles, and adds or takes away those BUs only.
  # Appointing BU Admins, hiding units and deleting people stay with AIM admins.
  class BuAdminPeopleTest < ActionController::TestCase
    tests Aim::MembersController

    setup do
      @employee = Employee.where.not(unit: [nil, '']).where.not(unit: '4703').order(:id).first
      skip 'no employee to test with' if @employee.nil?
      session[:user] = { 'email' => 'bu.admin@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set[] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4703', bu_admin: true)
    end

    test 'adds someone to AIM with their BU, and comes back to My BUs' do
      post :create, params: { employee_id: @employee.id, budget_unit: '4703' }

      assert_redirected_to aim_budget_units_path
      assert Aim::Member.exists?(employee_id: @employee.id)
      assert Aim::UserBudgetUnit.exists?(employee_id: @employee.id, budget_unit: '4703')
    end

    test 'cannot add someone with a BU they do not administer, or with none' do
      post :create, params: { employee_id: @employee.id, budget_unit: '4601' }
      assert_match(/only add people to your own/, flash[:alert])

      post :create, params: { employee_id: @employee.id }
      assert_match(/only add people to your own/, flash[:alert])
      assert_not Aim::Member.exists?(employee_id: @employee.id)
    end

    test "opens the profile of someone in their BU, without Delete, and no one else's" do
      Aim::Member.create!(employee_id: @employee.id)

      get :show, params: { id: @employee.id }
      assert_redirected_to aim_budget_units_path

      Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '4703')
      get :show, params: { id: @employee.id }
      assert_response :success
      assert_select 'button', text: 'Delete from AIM', count: 0
      assert_select 'button', text: 'Make BU Admin', count: 0
    end

    test 'cannot delete anyone' do
      Aim::Member.create!(employee_id: @employee.id)

      delete :destroy, params: { id: @employee.id, confirm_employee_id: @employee.id }

      assert_redirected_to aim_root_path
      assert Aim::Member.exists?(employee_id: @employee.id)
    end
  end
end
