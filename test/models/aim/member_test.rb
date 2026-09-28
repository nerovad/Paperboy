# frozen_string_literal: true

require 'test_helper'

module Aim
  # What Fusion said about a person, and the BU Admins it sets at go-live (a.2).
  class MemberTest < ActiveSupport::TestCase
    test "a Fusion supervisor becomes BU Admin of their team's BU, and app admins are listed, not granted" do
      people = Employee.where(unit: '4703').order(:id).limit(2).to_a
      boss = Employee.where.not(unit: '4703').order(:id).first
      skip 'need people in 4703 and one elsewhere' if people.size < 2 || boss.nil?
      people.each { |e| Aim::Member.create!(employee_id: e.id, fusion_team: 'GSA Maintenance') }
      Aim::Member.create!(employee_id: boss.id, fusion_team: 'System Team',
                          fusion_roles: 'app admin; supervisor; supervises GSA Maintenance')

      assert_equal ['4703'], Aim::Member.fusion_team_units['GSA Maintenance']
      made, app_admins = Aim::Member.apply_fusion_roles!(granted_by: 'test')

      assert_equal [[boss.id, '4703']], made
      assert_equal [boss.id], app_admins
      assert_equal ['4703'], Aim::Users.administered_budget_units(boss.id)
      assert_equal [[], [boss.id]], Aim::Member.apply_fusion_roles!(granted_by: 'test'), 'a second run changes nothing'
    end

    test 'the import keeps Fusion team and roles, also for people already listed' do
      employee = Employee.order(:id).first || skip('no employee to test with')
      Aim::Member.create!(employee_id: employee.id)
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'fusion.csv')
        File.write(path, "employee_id,name,fusion_team,fusion_roles\n#{employee.id},X,GSA Parks,supervisor\n")

        assert_equal [0, 1, []], Aim::Member.import_csv!(path, added_by: 'test')
      end
      member = Aim::Member.find_by!(employee_id: employee.id)
      assert_equal ['GSA Parks', 'supervisor'], [member.fusion_team, member.fusion_roles]
    end
  end
end
