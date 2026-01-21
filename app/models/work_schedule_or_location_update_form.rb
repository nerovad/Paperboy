class WorkScheduleOrLocationUpdateForm < ApplicationRecord
enum :status, {
  submitted: 0,
    step_1_pending: 1,
    step_1_approved: 2,
    step_2_pending: 3,
    approved: 4,
    denied: 5
}

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # For inbox queue display
  def status_label
    status
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
