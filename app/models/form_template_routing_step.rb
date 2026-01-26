class FormTemplateRoutingStep < ApplicationRecord
  belongs_to :form_template
  belongs_to :form_template_status, optional: true

  ROUTING_TYPES = %w[supervisor department_head employee].freeze

  validates :step_number, presence: true, numericality: { greater_than: 0 }
  validates :routing_type, presence: true, inclusion: { in: ROUTING_TYPES }
  validates :employee_id, presence: true, if: :routes_to_employee?
  validates :step_number, uniqueness: { scope: :form_template_id }

  scope :ordered, -> { order(:step_number) }

  def routes_to_employee?
    routing_type == 'employee'
  end

  def routing_label
    case routing_type
    when 'supervisor'
      'Supervisor'
    when 'department_head'
      'Department Head'
    when 'employee'
      employee_name || "Employee ##{employee_id}"
    end
  end

  def employee_name
    return nil unless employee_id
    employee = Employee.find_by(EmployeeID: employee_id)
    employee ? "#{employee.First_Name} #{employee.Last_Name}" : nil
  rescue
    nil
  end

  # Returns the status to apply when a form reaches this step
  def status_to_apply
    form_template_status
  end
end
