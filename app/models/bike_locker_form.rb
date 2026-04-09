class BikeLockerForm < ApplicationRecord
  include TrackableStatus

enum :status, {
  submitted: 0,
    step_1_pending: 1,
    approved: 2,
    denied: 3
}, default: :submitted

# Normalized status categories for cross-form reporting
STATUS_CATEGORIES = {
  submitted: :pending,
    step_1_pending: :in_review,
    approved: :approved,
    denied: :denied
}.freeze

# Human-readable status labels
STATUS_LABELS = {
  submitted: "Submitted",
    step_1_pending: "Sent to Reyleen Dowler",
    approved: "Approved",
    denied: "Denied"
}.freeze

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
  validate :column_names_must_be_valid_identifiers

  # Rejects any column name starting with a digit — these break ERB symbol syntax.
  # e.g. :30_day_spending_limit is invalid; use :spending_limit_30_day instead.
  def column_names_must_be_valid_identifiers
    self.class.column_names.each do |col|
      unless col.match?(/\A[a-zA-Z_]/)
        errors.add(:base, "Column '#{col}' is invalid: names must start with a letter or underscore, not a number.")
      end
    end
  end

  # For inbox queue display
  def status_label
    self.class.const_defined?(:STATUS_LABELS) ? (self.class::STATUS_LABELS[status&.to_sym] || status&.to_s&.humanize || "Unknown") : (status&.to_s&.humanize || "Unknown")
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
