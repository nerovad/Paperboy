class ParkingLotSubmission < ApplicationRecord
  include PhoneNumberable
  include Reassignable
  include TrackableStatus

enum :status, {
  in_progress: "in_progress",
    pending_delegated_approval: "pending_delegated_approval",
    step_1_pending: "step_1_pending",
    step_2_pending: "step_2_pending",
    step_3_pending: "step_3_pending",
    step_4_pending: "step_4_pending",
    denied: "denied",
    approved: "approved"
}, default: :in_progress

  # Links this hand-written model to its form-builder template so TrackableStatus
  # can run the UI-defined routing steps (Authorization -> Sean Payne -> GSA_Security).
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end

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
  
  def current_assignee_id
    if pending_delegated_approval?
      delegated_approver_id
    else
      supervisor_id
    end
  end

  def assignment_field_name
    if pending_delegated_approval?
      'delegated_approver_id'
    else
      'supervisor_id'
    end
  end
end
