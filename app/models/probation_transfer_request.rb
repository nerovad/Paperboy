class ProbationTransferRequest < ApplicationRecord
  include PhoneNumberable
  include Reassignable
  include TrackableStatus

  # === Lookups (stored columns are codes/IDs: agency, division, department, unit)
  belongs_to :agency_record,
             class_name: 'Agency',
             primary_key: :agency_id,
             foreign_key: :agency,
             optional: true

  belongs_to :division_record,
             class_name: 'Division',
             primary_key: :division_id,
             foreign_key: :division,
             optional: true

  belongs_to :department_record,
             class_name: 'Department',
             primary_key: :department_id,
             foreign_key: :department,
             optional: true

  belongs_to :unit_record,
             class_name: 'Unit',
             primary_key: :unit_id,
             foreign_key: :unit,
             optional: true

  # === Friendly display helpers ===
  def agency_long_name     = agency_record&.long_name     || agency
  def division_long_name   = division_record&.long_name   || division
  def department_long_name = department_record&.long_name || department
  def unit_long_name       = unit_record&.long_name       || unit

  # EXACT format you want everywhere for Unit:
  def unit_display
    if unit.present? && unit_long_name.present?
      "#{unit} - #{unit_long_name}"
    elsif unit_long_name.present?
      unit_long_name
    else
      unit.to_s
    end
  end

  enum :status, {
    in_progress: 'in_progress',
    manager_approved: 'manager_approved',
    denied: 'denied'
  }, default: :in_progress

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }

  scope :not_canceled, -> { where(canceled_at: nil) }
  scope :not_expired,  -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :active,       -> { in_progress.not_canceled.not_expired } # active = in_progress and still valid

  # Surface the cancellation state on top of the workflow status; otherwise the
  # label comes from form_template_statuses via TrackableStatus.
  def status_label
    return 'Canceled' if canceled_at.present?

    super
  end

  def ensure_expires!
    return if expires_at.present?

    base = created_at || Time.current
    update_columns(expires_at: base + 1.year, updated_at: Time.current)
  end

  def cancel!(reason:)
    return if canceled_at.present?

    update_columns(canceled_at: Time.current, canceled_reason: reason, updated_at: Time.current)
  end

  def expire_if_due!
    return if canceled_at.present?
    return if expires_at.blank? || expires_at > Time.current

    update_columns(canceled_at: Time.current, canceled_reason: 'expired', updated_at: Time.current)
  end

  def desired_destinations_array
    v = desired_transfer_destination
    return v if v.is_a?(Array)

    v.to_s
     .split(/[;,|]/) # split on ; or , or |
     .map(&:strip)
     .reject(&:blank?)
  end

  # Reassignable concern implementation
  def current_assignee_id
    supervisor_id
  end

  def assignment_field_name
    'supervisor_id'
  end
end
