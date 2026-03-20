class ParkingLotSubmission < ApplicationRecord
  include PhoneNumberable
  include Reassignable
  include TrackableStatus

enum :status, {
  submitted: 0,
    pending_delegated_approval: 1,
    denied: 2,
    approved: 3,
    sent_to_security: 4
}, default: :submitted

# Normalized status categories for cross-form reporting
STATUS_CATEGORIES = {
  submitted: :pending,
    pending_delegated_approval: :in_review,
    denied: :denied,
    approved: :approved,
    sent_to_security: :in_review
}.freeze

# Human-readable status labels
STATUS_LABELS = {
  submitted: "Submitted",
    pending_delegated_approval: "Pending delegated approval",
    denied: "Denied",
    approved: "Approved",
    sent_to_security: "Sent to security"
}.freeze

  # Stored columns on this model for org hierarchy are *codes/IDs*:
  #   agency, division, department, unit
  # === Associations to lookup tables (resolve codes -> LongName) ===
  belongs_to :agency_record,
             class_name: "Agency",
             primary_key: :agency_id,
             foreign_key: :agency,
             optional: true
  belongs_to :division_record,
             class_name: "Division",
             primary_key: :division_id,
             foreign_key: :division,
             optional: true
  belongs_to :department_record,
             class_name: "Department",
             primary_key: :department_id,
             foreign_key: :department,
             optional: true
  belongs_to :unit_record,
             class_name: "Unit",
             primary_key: :unit_id,
             foreign_key: :unit,
             optional: true
  # === Display helpers (use these in PDF/status views) ===
  def agency_long_name     = agency_record&.long_name     || agency
  def division_long_name   = division_record&.long_name   || division
  def department_long_name = department_record&.long_name || department
  def unit_long_name       = unit_record&.long_name       || unit
  # New: Unit display with "unit_id - long_name"
  def unit_display
    if unit.present? && unit_long_name.present?
      "#{unit} - #{unit_long_name}"
    elsif unit_long_name.present?
      unit_long_name
    else
      unit.to_s
    end
  end
  # Vehicles
  has_many :parking_lot_vehicles, dependent: :destroy
  accepts_nested_attributes_for :parking_lot_vehicles, allow_destroy: true
  # Status enum - provides submitted?, approved?, etc. automatically

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
  
  # With enum, status returns a symbol like :submitted, :approved, etc.
  def status_label
  self.class.const_defined?(:STATUS_LABELS) ? (self.class::STATUS_LABELS[status&.to_sym] || status&.to_s&.humanize || "Unknown") : (status&.to_s&.humanize || "Unknown")
end

  def assignment_field_name
    if pending_delegated_approval?
      'delegated_approver_id'
    else
      'supervisor_id'
    end
  end
end
