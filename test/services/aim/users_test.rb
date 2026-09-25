# frozen_string_literal: true

require 'test_helper'

module Aim
  # Who an invoice can be handed to: the AIM list and the aim_admin group.
  class UsersTest < ActiveSupport::TestCase
    test 'the aim_admin group are AIM users, and old queue grants and other groups are not' do
      employee = Employee.order(:id).first
      skip 'no employee to test with' if employee.nil?
      admins = Group.create!(Group_Name: 'aim_admin')
      granted = Group.create!(Group_Name: 'fleet_clerks')
      GroupPermission.create!(GroupID: granted.GroupID, Permission_Type: 'feature',
                              Permission_Key: AppFeature.permission_key('aim', 'processing_queues'))
      staff = Group.create!(Group_Name: 'aim_staff')
      EmployeeGroup.create!(GroupID: admins.GroupID, EmployeeID: employee.id)
      other = Employee.where.not(id: employee.id).order(:id).first
      [granted, staff].each { |g| EmployeeGroup.create!(GroupID: g.GroupID, EmployeeID: other.id) } if other

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
      admins = Group.create!(Group_Name: 'aim_admin')
      EmployeeGroup.create!(GroupID: admins.GroupID, EmployeeID: employee.id)

      assert_equal 1, Aim::Member.seed_from_groups!(added_by: 'test')
      assert_equal 0, Aim::Member.seed_from_groups!(added_by: 'test')
      assert_equal [employee.id], Aim::Member.pluck(:employee_id)
    end

    test 'importing a CSV adds known employees once and skips unknown ids' do
      employee = Employee.order(:id).first
      skip 'no employee to test with' if employee.nil?
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'users.csv')
        File.write(path, "employee_id,name\n#{employee.id},Someone\n999999999,Nobody\n,Blank\n")

        assert_equal [1, 0, [999_999_999]], Aim::Member.import_csv!(path, added_by: 'test')
        assert_equal [0, 1, [999_999_999]], Aim::Member.import_csv!(path, added_by: 'test')
        assert_equal [employee.id], Aim::Member.pluck(:employee_id)
      end
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
