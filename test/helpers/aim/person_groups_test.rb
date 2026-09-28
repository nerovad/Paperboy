# frozen_string_literal: true

require 'test_helper'

module Aim
  # The grouped person picker's list: AIM users under each BU they work in.
  class PersonGroupsTest < ActionView::TestCase
    include Aim::AccessHelper

    test 'people are grouped under their home unit and granted BUs, labelled from the COA' do
      employee = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit')
      Aim::Member.create!(employee_id: employee.id)
      Aim::UserBudgetUnit.create!(employee_id: employee.id, budget_unit: '9998')

      groups = aim_person_groups.to_h { |unit, label, people| [unit, [label, people.map(&:last)]] }

      assert_equal [employee.id], groups.fetch(employee.unit).last
      assert_equal Aim::Units.new.label(employee.unit), groups.fetch(employee.unit).first
      assert_equal [employee.id], groups.fetch('9998').last, 'listed under every BU they work in'
    end

    test 'a hidden home unit does not list them there' do
      employee = Employee.where.not(unit: [nil, '']).order(:id).first || skip('no employee with a unit')
      Aim::Member.create!(employee_id: employee.id)
      Aim::UserBudgetUnit.create!(employee_id: employee.id, budget_unit: employee.unit, hidden: true)

      groups = aim_person_groups.to_h { |unit, _, people| [unit, people.map(&:last)] }

      assert_nil groups[employee.unit]
      assert_equal [employee.id], groups.fetch(nil)
    end
  end
end
