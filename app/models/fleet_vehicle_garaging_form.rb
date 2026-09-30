# frozen_string_literal: true

class FleetVehicleGaragingForm < ApplicationRecord
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    approved: 'approved',
    denied: 'denied'
  }, default: :in_progress

  include Reassignable

  has_many :fleet_vehicle_garaging_form_locations, dependent: :destroy
  accepts_nested_attributes_for :fleet_vehicle_garaging_form_locations, allow_destroy: true, reject_if: :all_blank

  # Answers a submission copies onto its vehicle (see FleetVehicle#apply_garaging_form!).
  APPLIED_COLUMNS = %w[
    assign_to other_assignee is_this_a_take_home_vehicle location other_location
    do_you_have_a_secondary_location secondary_location other_secondary_location
  ].freeze

  # A form is about one vehicle already on the fleet list (FleetVehicle, the
  # fleet master). There is no approval step: submitting copies the answers
  # onto that vehicle. Forms from before this carry no vehicle_number and have
  # nothing to copy.
  #
  # The vehicle's own details are read-only on the form, and a disabled select
  # is never posted, so they are taken from the fleet list here rather than
  # from the request. This also records who held the vehicle and where it was
  # garaged before this submission changed them.
  before_validation :copy_vehicle_details, if: -> { new_record? || will_save_change_to_vehicle_number? }
  after_save :apply_to_fleet_vehicle, if: :applies_to_fleet_vehicle?

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
  validate :vehicle_must_be_on_the_fleet_list, if: -> { new_record? || will_save_change_to_vehicle_number? }
  validate :column_names_must_be_valid_identifiers

  # Rejects any column name starting with a digit — these break ERB symbol syntax.
  # e.g. :30_day_spending_limit is invalid; use :spending_limit_30_day instead.
  def column_names_must_be_valid_identifiers
    self.class.column_names.each do |col|
      errors.add(:base, "Column '#{col}' is invalid: names must start with a letter or underscore, not a number.") unless col.match?(/\A[a-zA-Z_]/)
    end
  end

  # Who the vehicle is to be assigned to: the typed name when "Other" was picked.
  def assignee
    assign_to == 'Other' ? other_assignee : assign_to
  end

  # Primary garaging address: the typed one when "Other" was picked.
  def garaging_location
    location == 'Other' ? other_location : location
  end

  # Secondary garaging address, resolved the same way.
  def secondary_garaging_location
    secondary_location == 'Other' ? other_secondary_location : secondary_location
  end

  # When the vehicle's record last changed. Display only: the form's Last
  # Updated field looks this up from the fleet list and is never stored.
  # Formatted as Records shows it (Pacific time, :short) so the saved value
  # reads the same as the one autofilled when a vehicle is picked.
  def last_updated
    FormLookup.display_value(fleet_vehicle&.updated_at)
  end

  # For inbox queue filtering - returns the form type name
  def form_type
    self.class.name.demodulize.titleize
  end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= Forms::Template.find_by(class_name: self.class.name)
  end

  private

  def fleet_vehicle
    FleetVehicle.find_by(vehicle_number: vehicle_number) if vehicle_number.present?
  end

  def copy_vehicle_details
    vehicle = fleet_vehicle
    return unless vehicle

    self.year = vehicle.year
    self.make = vehicle.make
    self.model = vehicle.model
    self.vehicle_assigned_to = vehicle.assigned_to
    self.last_known_location = vehicle.garaging_location
  end

  # A new submission always updates its vehicle. An edit does only while this
  # is still the vehicle's latest form, so correcting an old submission never
  # overwrites what a newer one set.
  def applies_to_fleet_vehicle?
    return false if vehicle_number.blank?
    return true if saved_change_to_id?

    saved_changes.keys.intersect?(APPLIED_COLUMNS) &&
      FleetVehicle.exists?(vehicle_number: vehicle_number, fleet_vehicle_garaging_form_id: id)
  end

  def vehicle_must_be_on_the_fleet_list
    if vehicle_number.blank?
      errors.add(:vehicle_number, "can't be blank")
    elsif !FleetVehicle.exists?(vehicle_number: vehicle_number)
      errors.add(:vehicle_number, 'is not on the fleet list')
    end
  end

  # Raises on failure so the submission rolls back with it rather than
  # leaving a saved form whose vehicle never changed.
  def apply_to_fleet_vehicle
    FleetVehicle.find_by!(vehicle_number: vehicle_number).apply_garaging_form!(self)
  end
end
