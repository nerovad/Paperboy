class FormTemplateRoutingStep < ApplicationRecord
  belongs_to :form_template

  ROUTING_TYPES = %w[supervisor department_head employee group].freeze
  CONDITION_OPERATORS = %w[equals not_equals].freeze

  validates :step_number, presence: true, numericality: { greater_than: 0 }
  validates :routing_type, presence: true, inclusion: { in: ROUTING_TYPES }
  validates :employee_id, presence: true, if: :routes_to_employee?
  validates :group_id, presence: true, if: :routes_to_group?
  validates :step_number, uniqueness: { scope: :form_template_id }
  validates :condition_operator, inclusion: { in: CONDITION_OPERATORS }, allow_blank: true
  validates :condition_field_id, presence: true, if: -> { condition_operator.present? }

  scope :ordered, -> { order(:step_number) }

  def routes_to_employee?
    routing_type == 'employee'
  end

  def routes_to_group?
    routing_type == 'group'
  end

  def routing_label
    case routing_type
    when 'supervisor'
      'Supervisor'
    when 'department_head'
      'Department Head'
    when 'employee'
      employee_name || "Employee ##{employee_id}"
    when 'group'
      group_name || "Group ##{group_id}"
    end
  end

  def employee_name
    return nil unless employee_id
    employee = Employee.find_by(employee_id: employee_id)
    employee ? "#{employee.first_name} #{employee.last_name}" : nil
  rescue
    nil
  end

  def group_name
    return nil unless group_id
    Group.find_by(group_id: group_id)&.group_name
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

  # True when this step has a condition that gates whether it runs.
  def conditional?
    condition_field_id.present? && condition_operator.present?
  end

  # The form field this step's condition checks.
  def condition_field
    return nil unless condition_field_id
    form_template.form_fields.find_by(id: condition_field_id)
  end

  # Stable column name on the form record (e.g. "osha_reportable") used to read the value.
  def condition_field_name
    condition_field&.field_name
  end

  # Evaluates the condition against a submitted form record.
  # Returns true when the step has no condition or the condition matches; false otherwise.
  def matches?(form_record)
    return true unless conditional?
    name = condition_field_name
    return true if name.blank?
    actual = form_record.respond_to?(name) ? form_record.public_send(name) : nil
    case condition_operator
    when 'equals'
      actual.to_s == condition_value.to_s
    when 'not_equals'
      actual.to_s != condition_value.to_s
    else
      true
    end
  end

  # Human-readable summary of the condition for badges/display.
  def condition_label
    return nil unless conditional?
    field = condition_field
    return nil unless field
    op = condition_operator == 'not_equals' ? '≠' : '='
    %(Only if "#{field.label}" #{op} "#{condition_value}")
  end
end
