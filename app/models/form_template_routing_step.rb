class FormTemplateRoutingStep < ApplicationRecord
  attribute :inbox_buttons, :json, default: []

  belongs_to :form_template

  ROUTING_TYPES = %w[supervisor department_head employee group authorization].freeze
  CONDITION_OPERATORS = %w[equals not_equals].freeze
  ORG_FILTER_LEVELS = %w[agency division department unit].freeze
  ORG_FILTER_LABELS = {
    "agency" => "Agency",
    "division" => "Division",
    "department" => "Department",
    "unit" => "Unit"
  }.freeze

  validates :step_number, presence: true, numericality: { greater_than: 0 }
  validates :routing_type, presence: true, inclusion: { in: ROUTING_TYPES }
  validates :employee_id, presence: true, if: :routes_to_employee?
  validates :group_id, presence: true, if: :routes_to_group?
  validates :authorization_service_type, presence: true,
            inclusion: { in: AuthorizedApprover::SERVICE_TYPES.keys },
            if: :routes_to_authorization?
  validates :step_number, uniqueness: { scope: :form_template_id }
  validates :condition_operator, inclusion: { in: CONDITION_OPERATORS }, allow_blank: true
  validates :condition_operator, presence: true, if: -> { condition_field_name.present? }
  validates :org_filter_level, inclusion: { in: ORG_FILTER_LEVELS }, allow_blank: true
  validate :org_filter_only_for_group_routing

  scope :ordered, -> { order(:step_number) }

  # Guards against double-encoded JSON the way FormTemplate#inbox_buttons does.
  def inbox_buttons
    val = super
    return [] if val.nil?
    val = JSON.parse(val) while val.is_a?(String)
    val.is_a?(Array) ? val : []
  rescue JSON::ParserError
    []
  end

  def has_inbox_button?(button_type)
    inbox_buttons.include?(button_type.to_s)
  end

  # Text for the inbox Approve button at this step. An optional per-step
  # override (e.g. "Permit Printed") that still performs the normal approve
  # action; blank falls back to the default "Approve".
  def approve_button_text
    approve_button_label.presence || "Approve"
  end

  # Text for the inbox Deny button at this step, with the same override
  # semantics as approve_button_text.
  def deny_button_text
    deny_button_label.presence || "Deny"
  end

  def routes_to_employee?
    routing_type == "employee"
  end

  def routes_to_group?
    routing_type == "group"
  end

  def routes_to_authorization?
    routing_type == "authorization"
  end

  # Human label for the chosen authorization service type (e.g. "Parking Permits").
  def authorization_service_type_label
    AuthorizedApprover::SERVICE_TYPES[authorization_service_type] || authorization_service_type
  end

  def routing_label
    case routing_type
    when "supervisor"
      "Supervisor"
    when "department_head"
      "Department Head"
    when "employee"
      employee_name || "Employee ##{employee_id}"
    when "group"
      base = group_name || "Group ##{group_id}"
      org_filtered? ? "#{base} (submitter's #{org_filter_label})" : base
    when "authorization"
      "Authorized approver — #{authorization_service_type_label}"
    end
  end

  # True when this is a group-routed step that's narrowed to members who
  # share the submitter's value at the configured org level.
  def org_filtered?
    routes_to_group? && org_filter_level.present?
  end

  def org_filter_label
    ORG_FILTER_LABELS[org_filter_level]
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
    Group.find_by(GroupID: group_id)&.group_name
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
    condition_field_name.present? && condition_operator.present?
  end

  # The form field this step's condition checks. Looked up by stable
  # field_name so it survives form-field rebuilds that renumber ids.
  def condition_field
    return nil unless condition_field_name.present?
    form_template.form_fields.find_by(field_name: condition_field_name)
  end

  # Evaluates the condition against a submitted form record.
  # Returns true when the step has no condition or the condition matches; false otherwise.
  def matches?(form_record)
    return true unless conditional?
    actual = form_record.respond_to?(condition_field_name) ? form_record.public_send(condition_field_name) : nil
    case condition_operator
    when "equals"
      actual.to_s == condition_value.to_s
    when "not_equals"
      actual.to_s != condition_value.to_s
    else
      true
    end
  end

  # The concrete employee_ids that could act on `submission` at this step.
  # Centralizes the per-type resolution so the runtime guard (and anyone else)
  # can tell when a step would route to nobody. Mirrors how approver_id is set
  # in TrackableStatus and how the inbox surfaces group/authorization steps.
  def eligible_approver_ids(submission)
    case routing_type
    when "supervisor"
      sup = step_submitter_employee(submission)&.supervisor_id
      sup.present? ? [ sup.to_s ] : []
    when "department_head"
      head = step_submitter_department(submission)&.department_head_id
      head.present? ? [ head.to_s ] : []
    when "employee"
      employee_id.present? ? [ employee_id.to_s ] : []
    when "group"
      group_eligible_ids(submission)
    when "authorization"
      authorization_eligible_ids(submission)
    else
      []
    end
  rescue StandardError
    []
  end

  # Human-readable summary of the condition for badges/display.
  def condition_label
    return nil unless conditional?
    field = condition_field
    return nil unless field
    op = condition_operator == "not_equals" ? "≠" : "="
    %(Only if "#{field.label}" #{op} "#{condition_value}")
  end

  private

  def step_submitter_employee(submission)
    eid = submission.respond_to?(:employee_id) ? submission.employee_id : nil
    # Employee or Contractor — both expose supervisor_id/unit for routing.
    eid.present? ? Submitter.resolve(eid) : nil
  end

  # The submitter's department, derived from their unit — same chain the
  # department_head/authorization resolution uses in TrackableStatus.
  def step_submitter_department(submission)
    emp = step_submitter_employee(submission)
    return nil unless emp
    unit = Unit.find_by(unit_id: emp.unit)
    unit ? Department.find_by(department_id: unit.department_id) : nil
  end

  # Group members, narrowed to those sharing the submitter's value at the
  # configured org level when org filtering is on.
  def group_eligible_ids(submission)
    return [] unless group_id
    member_ids = EmployeeGroup.where(GroupID: group_id).pluck(:EmployeeID).map(&:to_s)
    return member_ids unless org_filtered?

    submitter_value = (submission.public_send(org_filter_level) if submission.respond_to?(org_filter_level))
    return [] if submitter_value.blank?

    members = Employee.where(id: member_ids).to_a
    if org_filter_level == "unit"
      members.select { |e| e.unit.to_s == submitter_value.to_s }.map { |e| e.id.to_s }
    else
      unit_ids = members.map(&:unit).compact.uniq
      units = unit_ids.any? ? Unit.where(unit_id: unit_ids).index_by { |u| u.unit_id.to_s } : {}
      col = "#{org_filter_level}_id"
      members.select do |e|
        u = units[e.unit.to_s]
        u && u.public_send(col).to_s == submitter_value.to_s
      end.map { |e| e.id.to_s }
    end
  end

  # Everyone holding this authorization for the submission's budget unit.
  def authorization_eligible_ids(submission)
    return [] if authorization_service_type.blank?
    return [] unless submission.respond_to?(:unit) && submission.unit.present?
    AuthorizedApprover.approver_ids_covering_unit(
      service_type: authorization_service_type,
      unit_id: submission.unit
    ).map(&:to_s)
  end

  def org_filter_only_for_group_routing
    return if org_filter_level.blank?
    return if routes_to_group?
    errors.add(:org_filter_level, "is only valid for group routing steps")
  end
end
