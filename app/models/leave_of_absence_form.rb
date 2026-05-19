class LeaveOfAbsenceForm < ApplicationRecord
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
    step_1_pending: "Sent to HCA_HR",
    approved: "Approved",
    denied: "Denied",
    cancelled: "Cancelled"
}.freeze

  has_many_attached :doctors_note_attachment

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
  validate :acceptable_doctors_note_attachment_files

  # For inbox queue display
  def status_label
    self.class.const_defined?(:STATUS_LABELS) ? (self.class::STATUS_LABELS[status&.to_sym] || status&.to_s&.humanize || "Unknown") : (status&.to_s&.humanize || "Unknown")
  end

  # For inbox reassignment - returns the current approver's ID
  def current_assignee_id
    approver_id
  end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end

def acceptable_doctors_note_attachment_files
  return unless doctors_note_attachment.attached?

  if doctors_note_attachment.count > 10
    errors.add(:doctors_note_attachment, "can have a maximum of 10 files")
  end

  doctors_note_attachment.each do |file|
    unless file.content_type.in?(%w[image/jpeg image/png image/gif application/pdf])
      errors.add(:doctors_note_attachment, "must be a JPEG, PNG, GIF, or PDF")
    end

    if file.byte_size > 10.megabytes
      errors.add(:doctors_note_attachment, "file size must be less than 10MB")
    end
  end
end

end
