class NoticeOfChangeForm < ApplicationRecord
  include TrackableStatus

enum :status, {
  in_progress: 0,
    step_1_pending: 1,
    approved: 2,
    denied: 3,
    cancelled: 4
}, default: :in_progress

# Normalized status categories for cross-form reporting
STATUS_CATEGORIES = {
  in_progress: :in_review,
    step_1_pending: :in_review,
    approved: :approved,
    denied: :denied,
    cancelled: :cancelled
}.freeze

# Human-readable status labels
STATUS_LABELS = {
  in_progress: "In Progress",
    step_1_pending: "Sent to Dana Vodantis",
    approved: "Approved",
    denied: "Denied",
    cancelled: "Cancelled"
}.freeze

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # For inbox queue display
  def status_label
  self.class.const_defined?(:STATUS_LABELS) ? (self.class::STATUS_LABELS[status&.to_sym] || status&.to_s&.humanize || "Unknown") : (status&.to_s&.humanize || "Unknown")
end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end
end
