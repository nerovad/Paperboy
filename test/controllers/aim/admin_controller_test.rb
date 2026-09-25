# frozen_string_literal: true

require 'test_helper'

module Aim
  # The Users & Queues screen (item a.1): who works AIM, and how.
  class AdminControllerTest < ActionController::TestCase
    tests Aim::AdminController

    setup do
      session[:user] = { 'email' => 'aim.admin@example.com', 'employee_id' => 42 }
    end

    test 'lists the people added on the screen and those in the AIM groups' do
      employees = Employee.order(:id).limit(2).to_a
      skip 'need two employees to test with' if employees.size < 2
      as_groups 'aim_admin'
      added, grouped = employees
      Aim::Member.create!(employee_id: added.id)
      group = Group.create!(Group_Name: 'aim_staff')
      EmployeeGroup.create!(GroupID: group.GroupID, EmployeeID: grouped.id)

      get :index

      assert_response :success
      assert_includes response.body, added.last_name
      assert_includes response.body, grouped.last_name
      assert_includes response.body, 'Through a group, under ACL'
    end

    test 'AIM staff are sent away' do
      as_groups 'aim_staff'

      get :index

      assert_redirected_to aim_root_path
    end

    private

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end
  end
end
