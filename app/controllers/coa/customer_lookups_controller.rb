# frozen_string_literal: true

module Coa
  class CustomerLookupsController < BaseController
    SEARCH_LIMIT = 20

    before_action -> { require_app_feature('coa', 'customer_lookup', fallback: coa_root_path) }

    def show; end

    def employees
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      matches = employee_matches(query)
                .order(:last_name, :first_name)
                .limit(SEARCH_LIMIT)
                .pluck(:id, :first_name, :last_name, :unit)

      render json: matches.map { |id, first, last, unit| employee_option(id, first, last, unit) }
    end

    def hierarchy
      employee = Employee.select(:id, :first_name, :last_name, :agency, :unit, :email, :work_phone)
                         .find(params[:employee_id])
      render json: hierarchy_for(employee)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Employee not found.' }, status: :not_found
    end

    private

    def employee_matches(query)
      return Employee.where(id: query) if query.match?(/\A\d+\z/)

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      Employee.where('first_name LIKE :query OR last_name LIKE :query', query: pattern)
    end

    def employee_option(id, first_name, last_name, unit)
      {
        value: id,
        label: "#{last_name}, #{first_name} (#{id})",
        unit: unit
      }
    end

    def hierarchy_for(employee)
      {
        employee: employee_option(employee.id, employee.first_name, employee.last_name, employee.unit),
        contact: { email: employee.email, phone: employee.work_phone },
        nodes: Coa::EmployeeHierarchy.call(employee)
      }
    end
  end
end
