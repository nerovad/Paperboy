# frozen_string_literal: true

require 'test_helper'

module Aim
  # A person's profile page, as an AIM admin sees it (item a.2): their
  # invoices in their queue and across the pipeline, and the delete pop-up.
  class MembersProfileTest < ActionController::TestCase
    tests Aim::MembersController

    setup do
      @employee = Employee.order(:id).first
      skip 'no employee to test with' if @employee.nil?
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
      as_groups 'aim_admin'
    end

    test 'In queue shows Ready for Approval; In pipeline shows the other stages, finished ones only on request' do
      Aim::Member.create!(employee_id: @employee.id)
      { 'B-RDY' => %w[ready_for_approval INV-11], 'B-REV' => %w[needs_review INV-22],
        'B-APP' => %w[approved INV-33], 'B-EXP' => %w[exported INV-44] }.each do |batch_id, (state, number)|
        Aim::Invoice.create!(actor: 'test', batch_id: batch_id, state: state, assigned_employee_id: @employee.id,
                             invoice_number: number)
      end

      get :show, params: { id: @employee.id }
      assert_includes response.body, 'INV-11'
      assert_not_includes response.body, 'INV-22'
      assert_includes response.body, 'Move selected'

      get :show, params: { id: @employee.id, tab: 'pipeline' }
      assert_includes response.body, 'INV-22'
      assert_includes response.body, 'INV-33'
      assert_not_includes response.body, 'INV-11'
      assert_not_includes response.body, 'INV-44', 'finished invoices are left out by default'

      get :show, params: { id: @employee.id, tab: 'pipeline', stages: %w[exported] }
      assert_includes response.body, 'INV-44'
      assert_not_includes response.body, 'INV-22'
    end

    test 'the delete pop-up explains what is in the way while invoices are open' do
      Aim::Member.create!(employee_id: @employee.id)
      Aim::Invoice.create!(actor: 'test', batch_id: 'B-OPEN', state: 'needs_review', assigned_employee_id: @employee.id)

      get :show, params: { id: @employee.id }

      assert_includes response.body, 'still owns 1 open invoice'
      assert_select 'input[name=confirm_employee_id]', count: 0
    end

    test 'an admin opens the queue of someone who works AIM through a group' do
      group = Group.create!(Group_Name: 'aim_staff')
      EmployeeGroup.create!(GroupID: group.GroupID, EmployeeID: @employee.id)
      Aim::Invoice.create!(actor: 'test', batch_id: 'B-GRP', state: 'ready_for_approval', assigned_employee_id: @employee.id,
                           invoice_number: 'INV-99')

      get :show, params: { id: @employee.id }

      assert_response :success
      assert_includes response.body, 'INV-99'
      assert_includes response.body, 'AIM Staff'
      assert_select 'button', text: 'Delete from AIM', count: 0
      assert_equal "/aim/admin/users/#{@employee.id}", session[:aim_queue_page], 'an invoice opened here returns here'
    end

    test "a leaver's queue still opens, so their invoices can be moved" do
      Aim::Member.create!(employee_id: 999_999_999)

      get :show, params: { id: 999_999_999 }

      assert_response :success
      assert_includes response.body, 'No longer in GSABSS'
    end

    test 'the queue of someone who does not work AIM is refused' do
      get :show, params: { id: @employee.id }

      assert_redirected_to aim_admin_path
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
