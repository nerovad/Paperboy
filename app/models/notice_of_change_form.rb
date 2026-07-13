# frozen_string_literal: true

class NoticeOfChangeForm < ApplicationRecord
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    approved: 'approved',
    denied: 'denied',
    cancelled: 'cancelled'
  }, default: :in_progress

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end
end
