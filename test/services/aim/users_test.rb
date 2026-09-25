# frozen_string_literal: true

require 'test_helper'

module Aim
  # Who an invoice can be handed to: the AIM groups and the ACL grant.
  class UsersTest < ActiveSupport::TestCase
    test 'members of the AIM groups and of groups granted the queues are AIM users, once each' do
      employee = Employee.order(:id).first
      skip 'no employee to test with' if employee.nil?
      staff = Group.create!(Group_Name: 'aim_staff')
      granted = Group.create!(Group_Name: 'fleet_clerks')
      GroupPermission.create!(GroupID: granted.GroupID, Permission_Type: 'feature', Permission_Key: Aim::Users::FEATURE)
      EmployeeGroup.create!(GroupID: staff.GroupID, EmployeeID: employee.id)
      EmployeeGroup.create!(GroupID: granted.GroupID, EmployeeID: employee.id)

      assert_equal [employee.id], Aim::Users.all.map(&:id)
      assert_equal ["#{employee.first_name} #{employee.last_name}".squish], Aim::Users.names
    end

    test 'people added on the Admin screen are AIM users, alongside the groups' do
      employee = Employee.order(:id).first
      skip 'no employee to test with' if employee.nil?
      Aim::Member.create!(employee_id: employee.id)

      assert_equal [employee.id], Aim::Users.all.map(&:id)
      assert Aim::Users.member?(employee.id)
    end

    test 'seeding from the groups adds each group member once' do
      employee = Employee.order(:id).first
      skip 'no employee to test with' if employee.nil?
      staff = Group.create!(Group_Name: 'aim_staff')
      EmployeeGroup.create!(GroupID: staff.GroupID, EmployeeID: employee.id)

      assert_equal 1, Aim::Member.seed_from_groups!(added_by: 'test')
      assert_equal 0, Aim::Member.seed_from_groups!(added_by: 'test')
      assert_equal [employee.id], Aim::Member.pluck(:employee_id)
    end

    test 'a group without the grant gives nobody' do
      employee = Employee.order(:id).first
      skip 'no employee to test with' if employee.nil?
      other = Group.create!(Group_Name: 'parking')
      EmployeeGroup.create!(GroupID: other.GroupID, EmployeeID: employee.id)

      assert_empty Aim::Users.all
    end
  end
end
