# Configurable workflow email attached to a form template. Fires on submission
# or on the approval/denial of a routing step (or the form's final outcome) and
# sends a templated email with optional PDF / media attachments.
#
# Modeled on FormTemplateCopyRecipient — same builder/save plumbing — but this
# actually delivers email (via FormWorkflowMailer) rather than recording a copy.
class FormTemplateEmailStep < ApplicationRecord
  belongs_to :form_template

  TRIGGER_EVENTS = %w[submit approved denied].freeze
  RECIPIENT_TYPES = %w[submitter employee group custom_email form_field].freeze

  validates :trigger_event, presence: true, inclusion: { in: TRIGGER_EVENTS }
  validates :recipient_type, presence: true, inclusion: { in: RECIPIENT_TYPES }
  validates :employee_id, presence: true, if: -> { recipient_type == 'employee' }
  validates :group_id, presence: true, if: -> { recipient_type == 'group' }
  validates :custom_email, presence: true, if: -> { recipient_type == 'custom_email' }
  validates :recipient_field_name, presence: true, if: -> { recipient_type == 'form_field' }

  scope :ordered, -> { order(:position, :id) }

  # Rules matching a given event. For approved/denied, `step_number` selects
  # between a specific step (integer) and the final outcome (nil).
  scope :for_event, lambda { |event, step_number: :__any__|
    rel = where(trigger_event: event.to_s)
    return rel if step_number == :__any__

    rel.where(routing_step_number: step_number)
  }

  # True when this email is bound to a specific routing step's action rather
  # than the form's final approved/denied outcome.
  def step_bound?
    %w[approved denied].include?(trigger_event) && routing_step_number.present?
  end

  # Resolve this rule into concrete recipient email addresses for `submission`.
  def resolve_recipient_emails(submission)
    case recipient_type
    when 'submitter'
      [submission.try(:email)].compact_blank
    when 'employee'
      [Employee.find_by(employee_id: employee_id)&.email].compact_blank
    when 'group'
      return [] unless group_id

      member_ids = EmployeeGroup.where(GroupID: group_id).pluck(:EmployeeID)
      Employee.where(id: member_ids).pluck(:email).compact_blank
    when 'custom_email'
      [custom_email].compact_blank
    when 'form_field'
      return [] unless recipient_field_name.present?

      [submission.try(recipient_field_name)].compact_blank
    else
      []
    end
  rescue StandardError
    []
  end

  def render_subject(submission)
    FormEmailRenderer.render(subject, submission)
  end

  def render_body(submission)
    FormEmailRenderer.render(body, submission)
  end

  # --- Builder display helpers ---

  def trigger_label
    case trigger_event
    when 'submit'   then 'On submission'
    when 'approved' then step_bound? ? "On approval of Step #{routing_step_number}" : 'On final approval'
    when 'denied'   then step_bound? ? "On denial of Step #{routing_step_number}" : 'On final denial'
    else trigger_event.to_s.humanize
    end
  end

  def recipient_label
    case recipient_type
    when 'submitter' then 'Submitter'
    when 'employee'
      emp = Employee.find_by(employee_id: employee_id)
      emp ? "#{emp.first_name} #{emp.last_name}" : "Employee ##{employee_id}"
    when 'group'        then Group.find_by(GroupID: group_id)&.group_name || "Group ##{group_id}"
    when 'custom_email' then custom_email
    when 'form_field'   then "Form field: #{recipient_field_name}"
    end
  rescue StandardError
    recipient_type.to_s.humanize
  end
end
