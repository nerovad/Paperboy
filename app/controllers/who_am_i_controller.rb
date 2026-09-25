# frozen_string_literal: true

# The body of the "Who Am I" dialog. It is only ever fetched into that
# dialog's turbo-frame, so it renders without a layout — the layout carries
# the dialog, and the dialog carries a frame of the same name.
class WhoAmIController < ApplicationController
  # Fetched into a dialog, and answers a signed-out visitor with its own 403
  # rather than a redirect to a page.
  skip_before_action :require_sign_in

  layout false

  def show
    return head(:forbidden) unless current_user

    employee = Employee.find_by!(employee_id: current_user.employee_id)
    @customer_name = "#{employee.last_name}, #{employee.first_name} (#{employee.employee_id})"
    @hierarchy_nodes = Coa::EmployeeHierarchy.call(employee)
  rescue ActiveRecord::RecordNotFound
    @error = 'Employee record not found.'
  end
end
