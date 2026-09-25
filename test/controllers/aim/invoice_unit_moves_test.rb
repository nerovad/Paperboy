# frozen_string_literal: true

require 'test_helper'

module Aim
  # Moving an invoice to another budget unit's shared queue (item a.2): it
  # changes the invoice's BU, so the mover must cover that BU unless they are
  # AIM Staff or an Admin.
  class InvoiceUnitMovesTest < ActionController::TestCase
    tests Aim::InvoicesController

    setup do
      session[:user] = { 'email' => 'mover@example.com', 'employee_id' => 7 }
      @controller.define_singleton_method(:current_user_group_names) { Set['aim_staff'] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    test 'staff move an invoice to another BU shared queue, and the history says the BU changed' do
      row = invoice('U-1', budget_unit: '4641', assigned_employee_id: 7, assigned_to: 'Jane Doe', assignment_source: 'folder')

      patch :reassign, params: { id: row.batch_id, destination: 'other_unit', budget_unit: '4601' }

      row.reload
      assert_equal '4601', row.budget_unit
      assert_nil row.assigned_employee_id
      assert_match(/budget unit changed from 4641 to 4601/, row.events.last.note)
      assert_match(/4601 shared queue/, flash[:notice])
    end

    test 'many at once' do
      a = invoice('U-2', budget_unit: '4641')
      b = invoice('U-3', budget_unit: '4643')

      patch :reassign_many, params: { ids: [a.batch_id, b.batch_id], destination: 'other_unit', budget_unit: '4601' }

      assert_equal %w[4601 4601], [a.reload.budget_unit, b.reload.budget_unit]
      assert_match(/Moved 2 invoices/, flash[:notice])
    end

    test 'a User moves only to a BU they cover' do
      as_user
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4601')
      row = invoice('U-4', budget_unit: '4641', assigned_employee_id: 7, assigned_to: 'Jane Doe', assignment_source: 'folder')

      patch :reassign, params: { id: row.batch_id, destination: 'other_unit', budget_unit: '4999' }
      assert_equal '4641', row.reload.budget_unit
      assert_match(/cannot move invoices to that budget unit/, flash[:alert])

      patch :reassign, params: { id: row.batch_id, destination: 'other_unit', budget_unit: '4601' }
      assert_equal '4601', row.reload.budget_unit
    end

    test 'Approver mode moves as a User does' do
      session[:aim_mode] = 'approver'
      row = invoice('U-5', budget_unit: '4641', assigned_employee_id: 7, assigned_to: 'Jane Doe', assignment_source: 'folder')

      patch :reassign, params: { id: row.batch_id, destination: 'other_unit', budget_unit: '4999' }

      assert_equal '4641', row.reload.budget_unit
    end

    test 'a BU Admin moves an invoice in their BU only to someone who covers it' do
      as_user
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4641', bu_admin: true)
      insider, outsider = Employee.order(:id).limit(2).to_a
      skip 'need two employees' if outsider.nil?
      [insider, outsider].each { |e| Aim::Member.create!(employee_id: e.id) }
      Aim::UserBudgetUnit.create!(employee_id: insider.id, budget_unit: '4641')
      row = invoice('U-6', budget_unit: '4641', assigned_employee_id: 99, assigned_to: 'Someone Else',
                           assignment_source: 'folder')

      patch :reassign, params: { id: row.batch_id, destination: 'person', owner: outsider.id }
      assert_match(/does not cover 4641/, flash[:alert]) unless Aim::Users.shared_budget_units(outsider.id, staff: false).include?('4641')

      patch :reassign, params: { id: row.batch_id, destination: 'person', owner: insider.id }
      assert_equal insider.id, row.reload.assigned_employee_id
    end

    test "a BU Admin may claim but not approve someone else's invoice" do
      as_user
      Aim::UserBudgetUnit.create!(employee_id: 7, budget_unit: '4641', bu_admin: true)
      row = invoice('U-7', budget_unit: '4641', assigned_employee_id: 99, assigned_to: 'Someone Else',
                           assignment_source: 'folder')

      patch :update, params: { id: row.batch_id, commit: 'Approve' }
      assert_equal 'ready_for_approval', row.reload.state
    end

    private

    def invoice(batch_id, **attributes)
      Aim::Invoice.create!(batch_id: batch_id, state: 'ready_for_approval', actor: 'test', document_type: 'Invoice',
                           vendor_name: 'ACME', invoice_number: batch_id, **attributes)
    end

    def as_user
      @controller.define_singleton_method(:current_user_group_names) { Set[] }
      @controller.helpers.define_singleton_method(:can_use_app_feature?) { |*| false }
    end
  end
end
