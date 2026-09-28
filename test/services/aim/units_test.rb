# frozen_string_literal: true

require 'test_helper'

module Aim
  # Agencies and budget units from the Chart of Accounts (Joshua, 2026-09-25).
  class UnitsTest < ActiveSupport::TestCase
    test 'the agencies AIM serves are those of the people who work AIM, in COA spelling' do
      employee = Employee.where('agency LIKE ?', 'GSA%').order(:id).first || skip('no GSA employee')
      Aim::Member.create!(employee_id: employee.id)

      assert_equal ['GSA'], Aim::Units.new.agencies
    end

    test 'with nobody listed it falls back to GSA' do
      assert_equal ['GSA'], Aim::Units.new.agencies
    end

    test 'tidies the COA capitals, keeping agency codes and lowering small words' do
      skip 'GSA is not an agency in this COA' unless Coa::Agency.exists?(agency_id: 'GSA')

      assert_equal 'GSA Administration', Aim::Units.tidy('GSA ADMINISTRATION')
      assert_equal 'Warehouse and Distribution Services', Aim::Units.tidy('WAREHOUSE AND DISTRIBUTION SERVICES')
    end

    test 'labels and groups units from the COA' do
      unit = Coa::Unit.where(agency_id: 'GSA', active: true).order(:unit_id).first || skip('no GSA unit in the COA')
      units = Aim::Units.new

      assert_equal "#{unit.unit_id} · #{Aim::Units.tidy(unit.long_name)}", units.label(unit.unit_id)
      assert_equal 'GSA', units.agency_of(unit.unit_id)
      group = units.grouped_options(only: [unit.unit_id])
      assert_equal 1, group.size
      assert_match(/\AGSA/, group.first.first)
      assert_equal [[units.label(unit.unit_id), unit.unit_id]], group.first.last
      assert_equal 'No BU', units.label(nil)
      assert_equal 'ZZZZ', units.label('ZZZZ')
    end
  end
end
