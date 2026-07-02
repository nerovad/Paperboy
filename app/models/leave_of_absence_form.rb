class LeaveOfAbsenceForm < ApplicationRecord
  include TrackableStatus

enum :status, {
  in_progress: "in_progress",
    step_1_pending: "step_1_pending",
    approved: "approved",
    denied: "denied",
    cancelled: "cancelled"
}, default: :in_progress

  has_many_attached :doctors_note_attachment

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
  validate :acceptable_doctors_note_attachment_files

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
