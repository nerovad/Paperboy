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

    test 'a person\'s home unit is their unit as the Chart of Accounts has it' do
      hca = Employee.new(agency: 'HCA', unit: '8123')
      parent = Struct.new(:unit_id).new('8100')

      Coa::Unit.stub(:resolve_for_employee, parent) { assert_equal '8100', Aim::Users.home_unit(hca) }
      Coa::Unit.stub(:resolve_for_employee, nil) { assert_equal '8123', Aim::Users.home_unit(hca) }
      assert_nil Aim::Users.home_unit(nil)
    end

    test 'home units for many people ask the Chart of Accounts once per agency and unit' do
      asked = []
      Coa::Unit.stub(:resolve_for_employee, lambda { |employee|
        asked << employee.unit
        nil
      }) do
        units = Aim::Users.home_units(1 => %w[GSA 4601], 2 => %w[GSA 4601], 3 => ['GSA', nil])

        assert_equal({ 1 => '4601', 2 => '4601', 3 => nil }, units)
      end
      assert_equal ['4601'], asked
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

    test 'an active BU with people but no BU Admin is reported, until someone administers it' do
      employee = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit')
      Aim::Member.create!(employee_id: employee.id)

      assert_includes Aim::Users.units_without_admin, employee.unit

      Aim::UserBudgetUnit.create!(employee_id: employee.id, budget_unit: employee.unit, bu_admin: true)
      assert_not_includes Aim::Users.units_without_admin, employee.unit
    end

    test 'deactivated people do not make a BU active' do
      employee = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit')
      Aim::Member.create!(employee_id: employee.id, deactivated_at: Time.current)

      assert_not_includes Aim::Users.units_without_admin, employee.unit
    end
  end
end
