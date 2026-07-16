# frozen_string_literal: true

class OshaReport < ApplicationRecord
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    approved: 'approved',
    denied: 'denied'
  }, default: :in_progress

  belongs_to :safety_report, optional: true

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Narrow to an Agency → Division → Department → Unit selection. Each level is
  # optional; a blank value leaves that level unfiltered ("all"). The org
  # columns store the GSABSS id values as strings. Powers the OSHA 300 portal
  # filters (300 Log + 300A Summary).
  scope :org_filtered, lambda { |filters|
    filters = (filters || {}).symbolize_keys
    rel = all
    rel = rel.where(agency: filters[:agency]) if filters[:agency].present?
    rel = rel.where(division: filters[:division]) if filters[:division].present?
    rel = rel.where(department: filters[:department]) if filters[:department].present?
    rel = rel.where(unit: filters[:unit]) if filters[:unit].present?
    rel
  }

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
