# frozen_string_literal: true

class BikeLockerForm < ApplicationRecord
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    approved: 'approved',
    denied: 'denied'
  }, default: :in_progress

  # The physical locker being requested. Keyed on id, not number, because a
  # locker_number repeats across lots (E/R/ECCH/Saticoy all have a "1").
  belongs_to :locker, class_name: 'BikeLocker', optional: true

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
  validate :column_names_must_be_valid_identifiers

  # Snapshot the chosen locker's lot + number onto the request for display/PDF,
  # so the record reads correctly even if locker reference data changes later.
  before_validation :snapshot_locker_details, if: :locker

  # Guard against two people requesting the same locker. Allowed if the locker
  # is free, or already held by this same employee (edit / re-submit).
  validate :locker_must_be_available, if: -> { locker && will_save_change_to_locker_id? }

  # --- Locker lifecycle (called from the controller alongside status changes) ---
  # Submission reserves the locker; final approval assigns it; denial frees it.
  def reserve_locker!
    locker&.update!(status: :reserved, assigned_employee_id: employee_id.to_s, assigned_at: Time.current)
  end

  def assign_locker!
    locker&.update!(status: :assigned, assigned_employee_id: employee_id.to_s, assigned_at: Time.current)
  end

  def release_locker!
    locker&.update!(status: :available, assigned_employee_id: nil, assigned_at: nil)
  end

  # Rejects any column name starting with a digit — these break ERB symbol syntax.
  # e.g. :30_day_spending_limit is invalid; use :spending_limit_30_day instead.
  def column_names_must_be_valid_identifiers
    self.class.column_names.each do |col|
      errors.add(:base, "Column '#{col}' is invalid: names must start with a letter or underscore, not a number.") unless col.match?(/\A[a-zA-Z_]/)
    end
  end

  def snapshot_locker_details
    self.locker_location = locker.lot.name
    self.locker_number   = locker.locker_number.to_s
  end

  def locker_must_be_available
    return if locker.available?
    return if locker.assigned_employee_id == employee_id.to_s

    errors.add(:locker_id, 'is no longer available — please choose another locker')
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
