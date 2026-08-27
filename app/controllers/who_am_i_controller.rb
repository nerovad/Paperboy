# frozen_string_literal: true

class WhoAmIController < ApplicationController
  def show
    return redirect_to(root_path) unless current_user

    employee = Employee.find_by!(employee_id: current_user.employee_id)
    @customer_name = "#{employee.last_name}, #{employee.first_name} (#{employee.employee_id})"
    @hierarchy_nodes = Coa::EmployeeHierarchy.call(employee)
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Employee record not found.'
  end
end
