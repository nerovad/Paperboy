# frozen_string_literal: true

require 'test_helper'

module Aim
  # Deactivating someone who left, and bringing them back (item a.2).
  class MemberStatusesControllerTest < ActionController::TestCase
    tests Aim::MemberStatusesController

    setup do
      @employee = Employee.where.not(unit: [nil, '']).where.not(unit: '4703').order(:id).first
      skip 'no employee to test with' if @employee.nil?
      @member = Aim::Member.create!(employee_id: @employee.id)
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
    end

    test 'deactivating takes them out of AIM users, and reactivating brings them back' do
      patch :deactivate, params: { id: @employee.id, reason: 'Left the county' }

      @member.reload
      assert_not @member.active?
      assert_equal 'Left the county', @member.deactivation_reason
      assert_equal 'aim.admin@example.com', @member.deactivated_by
      assert_not Aim::Users.member?(@employee.id)

      patch :reactivate, params: { id: @employee.id }
      assert @member.reload.active?
      assert Aim::Users.member?(@employee.id)
    end

    test 'someone who still owns invoices is not deactivated' do
      Aim::Invoice.create!(actor: 'test', batch_id: 'S-1', state: 'needs_review', assigned_employee_id: @employee.id)

      patch :deactivate, params: { id: @employee.id }

      assert_match(/Move their open invoices/, flash[:alert])
      assert @member.reload.active?
    end

    test 'a BU Admin deactivates only someone whose BUs are all theirs' do
      as_groups
      session[:user] = session[:user].merge('employee_id' => 7)
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4703', bu_admin: true)
      Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: '4703')

      patch :deactivate, params: { id: @employee.id }
      assert_match(/also work BUs you do not administer/, flash[:alert])
      assert @member.reload.active?

      Aim::UserBudgetUnit.create!(employee_id: @employee.id, budget_unit: @employee.unit, hidden: true)
      patch :deactivate, params: { id: @employee.id }
      assert_not @member.reload.active?
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
