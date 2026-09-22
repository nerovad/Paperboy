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

  # A form is about one vehicle already on the fleet list (FleetVehicle, the
  # fleet master); approval copies its answers onto that vehicle. Forms from
  # before this carry no vehicle_number and have nothing to copy.
  after_update :apply_to_fleet_vehicle, if: -> { saved_change_to_status? && approved? && vehicle_number.present? }

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

  # For inbox queue filtering - returns the form type name
  def form_type
    self.class.name.demodulize.titleize
  end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= Forms::Template.find_by(class_name: self.class.name)
  end

  private

  def vehicle_must_be_on_the_fleet_list
    if vehicle_number.blank?
      errors.add(:vehicle_number, "can't be blank")
    elsif !FleetVehicle.exists?(vehicle_number: vehicle_number)
      errors.add(:vehicle_number, 'is not on the fleet list')
    end
  end

  # Raises on failure so the approval rolls back with it rather than leaving
  # an approved form whose vehicle never changed.
  def apply_to_fleet_vehicle
    vehicle = FleetVehicle.find_by!(vehicle_number: vehicle_number)
    vehicle.apply_garaging_form!(self)
  end
end
