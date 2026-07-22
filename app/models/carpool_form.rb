# frozen_string_literal: true

class CarpoolForm < ApplicationRecord
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    denied: 'denied',
    approved: 'approved'
  }, default: :in_progress

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # For inbox reassignment - returns the current approver's ID
  def current_assignee_id
    approver_id
  end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end
end
