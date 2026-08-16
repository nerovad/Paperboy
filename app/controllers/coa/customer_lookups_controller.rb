# frozen_string_literal: true

module Coa
  class CustomerLookupsController < BaseController
    SEARCH_LIMIT = 20

    before_action -> { require_app_feature('coa', 'customer_lookup', fallback: coa_root_path) }

    def show; end

    def employees
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      matches = Employee.where('first_name LIKE :query OR last_name LIKE :query', query: pattern)
                        .order(:last_name, :first_name)
                        .limit(SEARCH_LIMIT)
                        .pluck(:id, :first_name, :last_name, :unit)

      render json: matches.map { |id, first, last, unit| employee_option(id, first, last, unit) }
    end

    def hierarchy
      employee = Employee.select(:id, :first_name, :last_name, :agency, :unit).find(params[:employee_id])
      render json: hierarchy_for(employee)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Employee not found.' }, status: :not_found
    end

    private

    def employee_option(id, first_name, last_name, unit)
      {
        value: id,
        label: "#{last_name}, #{first_name} (#{id})",
        unit: unit
      }
    end

    def hierarchy_for(employee)
      agency_id = ::Agency.normalize_id(employee.agency)
      sub_unit = hca_sub_unit(employee, agency_id)
      unit_id = sub_unit&.unit_id || employee.unit
      unit = Coa::Unit.find_by(agency_id: agency_id, unit_id: unit_id)

      {
        employee: employee_option(employee.id, employee.first_name, employee.last_name, employee.unit),
        nodes: hierarchy_nodes(unit, sub_unit)
      }
    end

    def hca_sub_unit(employee, agency_id)
      return unless agency_id == 'HCA'

      Coa::SubUnit.find_by(agency_id: agency_id, sub_unit_id: employee.unit)
    end

    def hierarchy_nodes(unit, sub_unit)
      return [] unless unit

      agency = Coa::Agency.find_by(agency_id: unit.agency_id)
      division = Coa::Division.find_by(agency_id: unit.agency_id, division_id: unit.division_id)
      department = Coa::Department.find_by(
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
