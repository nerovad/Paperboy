class FormTemplateCopyRecipient < ApplicationRecord
  belongs_to :form_template

  RECIPIENT_TYPES = %w[employee group supervisor].freeze
  TRIGGER_EVENTS = %w[submit approval either].freeze

  validates :recipient_type, presence: true, inclusion: { in: RECIPIENT_TYPES }
  validates :trigger_event, presence: true, inclusion: { in: TRIGGER_EVENTS }
  validates :employee_id, presence: true, if: -> { recipient_type == "employee" }
  validates :group_id, presence: true, if: -> { recipient_type == "group" }

  scope :ordered, -> { order(:position, :id) }
  scope :for_event, ->(event) { where(trigger_event: [ event.to_s, "either" ]) }

  # Resolve this config row into the concrete employee IDs that should receive
  # the copy for `submission`. Returns an array of stringified employee_ids
  # (matching how routing's approver_id is stored).
  def resolve_recipient_ids(submission)
    case recipient_type
    when "employee"
      [ employee_id.to_s ]
    when "supervisor"
      sup = submitter_supervisor_id(submission)
      sup ? [ sup.to_s ] : []
    when "group"
      return [] unless group_id
      EmployeeGroup.where(GroupID: group_id).pluck(:EmployeeID).map(&:to_s)
    else
      []
    end
  end

  def recipient_label
    case recipient_type
    when "employee"
      emp = Employee.find_by(employee_id: employee_id)
      emp ? "#{emp.first_name} #{emp.last_name}" : "Employee ##{employee_id}"
    when "group"
      Group.find_by(GroupID: group_id)&.group_name || "Group ##{group_id}"
    when "supervisor"
      "Submitter's supervisor"
    end
  rescue
    recipient_type.humanize
  end

  private

  def submitter_supervisor_id(submission)
    employee_id = submission.respond_to?(:employee_id) ? submission.employee_id : nil
    return nil unless employee_id
    Submitter.resolve(employee_id)&.supervisor_id
  rescue
    nil
  end
end
