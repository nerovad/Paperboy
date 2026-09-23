# frozen_string_literal: true

class ParkingLotSubmission < ApplicationRecord
  include PhoneNumberable
  include Reassignable
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    step_2_pending: 'step_2_pending',
    step_3_pending: 'step_3_pending',
    step_4_pending: 'step_4_pending',
    denied: 'denied',
    approved: 'approved'
  }, default: :in_progress

  # Links this hand-written model to its form-builder template so TrackableStatus
  # can run the UI-defined routing steps (Authorization -> Sean Payne -> GSA_Security).
  def form_template
    @form_template ||= Forms::Template.find_by(class_name: self.class.name)
  end

  # Stored columns on this model for org hierarchy are *codes/IDs*:
  #   agency, division, department, unit
  # === Associations to lookup tables (resolve codes -> LongName) ===
  belongs_to :agency_record,
             class_name: 'Coa::Agency',
             primary_key: :agency_id,
             foreign_key: :agency,
             optional: true
  belongs_to :division_record,
             class_name: 'Coa::Division',
             primary_key: :division_id,
             foreign_key: :division,
             optional: true
  belongs_to :department_record,
             class_name: 'Coa::Department',
             primary_key: :department_id,
             foreign_key: :department,
             optional: true
  belongs_to :unit_record,
             class_name: 'Coa::Unit',
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

  # The builder only knows this form as one custom "Vehicles" field, so the
  # per-vehicle permit types are offered to routing conditions here instead.
  def self.routing_condition_fields
    [Forms::RoutingConditionField.new(field_name: 'permit_types',
                                      label: 'Permit Type (any vehicle)',
                                      field_type: 'dropdown',
                                      dropdown_values: ParkingLotVehicle::PERMIT_TYPES)]
  end

  # Every permit type requested across the submission's vehicles, so a
  # routing step can run only when, say, any vehicle asks for 'R Lot'.
  def permit_types
    parking_lot_vehicles.reject(&:marked_for_destruction?)
                        .flat_map { |v| Array(v.permit_type) }.compact_blank.uniq
  end
  # Status enum - provides submitted?, approved?, etc. automatically

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }

  # The current step's assignee is tracked in approver_id (set by the routing
  # engine); reassignment writes the same column.
  def current_assignee_id
    approver_id
  end

  def assignment_field_name
    'approver_id'
  end
end
