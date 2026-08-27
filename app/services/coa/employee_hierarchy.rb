# frozen_string_literal: true

module Coa
  class EmployeeHierarchy
    def self.call(employee)
      new(employee).call
    end

    def initialize(employee)
      @employee = employee
    end

    def call
      agency_id = Agency.normalize_id(employee.agency)
      sub_unit = hca_sub_unit(agency_id)
      unit_id = sub_unit&.unit_id || employee.unit
      unit = Unit.find_by(agency_id: agency_id, unit_id: unit_id)

      hierarchy_nodes(unit, sub_unit)
    end

    private

    attr_reader :employee

    def hca_sub_unit(agency_id)
      return unless agency_id == 'HCA'

      SubUnit.find_by(agency_id: agency_id, sub_unit_id: employee.unit)
    end

    def hierarchy_nodes(unit, sub_unit)
      return [] unless unit

      agency = Agency.find_by(agency_id: unit.agency_id)
      division = Division.find_by(agency_id: unit.agency_id, division_id: unit.division_id)
      department = Department.find_by(
        agency_id: unit.agency_id,
        division_id: unit.division_id,
        department_id: unit.department_id
      )

      [
        node('Agency', unit.agency_id, agency&.long_name),
        node('Division', unit.division_id, division&.long_name),
        node('Department', unit.department_id, department&.long_name),
        node('Unit', unit.unit_id, unit.long_name),
        (node('Sub-Unit', sub_unit.sub_unit_id, sub_unit.sub_unit_name) if sub_unit)
      ].compact
    end

    def node(level, id, name)
      { level: level, id: id, name: name }
    end
  end
end
