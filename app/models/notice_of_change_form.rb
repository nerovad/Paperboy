class NoticeOfChangeForm < ApplicationRecord
  include TrackableStatus

enum :status, {
  in_progress: 0,
    approved: 1,
    denied: 2,
    cancelled: 3
}, default: :in_progress

# Normalized status categories for cross-form reporting
STATUS_CATEGORIES = {
  in_progress: :in_review,
    approved: :approved,
    denied: :denied,
    cancelled: :cancelled
}.freeze

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # For inbox queue display
  def status_label
    status&.to_s&.humanize || "Unknown"
  end

  # For inbox queue filtering - returns the form type name
  def form_type
    self.class.name.demodulize.titleize
  end

  # For inbox reassignment - returns the current approver's ID
  def current_assignee_id
    approver_id
  end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end
end
