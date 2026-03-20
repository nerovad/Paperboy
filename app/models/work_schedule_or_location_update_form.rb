class WorkScheduleOrLocationUpdateForm < ApplicationRecord

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

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
end
