class FormTemplateRoutingStep < ApplicationRecord
  belongs_to :form_template

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
    employee = Employee.find_by(employee_id: employee_id)
    employee ? "#{employee.first_name} #{employee.last_name}" : nil
  rescue
    nil
  end

  # Default display name for the pending status at this step
  def default_pending_display_name
    "Sent to #{routing_label}"
  end

  # Default display name for the approved status at this step
  def default_approved_display_name
    "#{routing_label} Approved"
  end

  # Pending display name: prefer user-set display_name, fall back to default
  def pending_display_name
    display_name.presence || default_pending_display_name
  end

  # Approved display name: derive from display_name or fall back to default
  def approved_display_name
    default_approved_display_name
  end
end
