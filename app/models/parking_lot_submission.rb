class ParkingLotSubmission < ApplicationRecord
  include PhoneNumberable

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

  # Status
  STATUS_MAP = {
    0 => "submitted",                    # Pending Dept Head approval
    1 => "pending_delegated_approval",   # Dept Head approved, awaiting delegated approver
    2 => "denied",
    3 => "approved",                     # Delegated approver approved
    4 => "sent_to_security"              # Final state
  }

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }

  def status_label
    STATUS_MAP[status]
  end

  def submitted?                    = status == 0
  def pending_delegated_approval?   = status == 1
  def denied?                       = status == 2
  def approved?                     = status == 3
  def sent_to_security?             = status == 4
end
