# frozen_string_literal: true

class SafetyReport < ApplicationRecord
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    approved: 'approved',
    denied: 'denied',
    cancelled: 'cancelled'
  }, default: :in_progress

  # Safety Report → OSHA Reporting field mapping
  OSHA_REPORT_FIELD_MAP = {
    employee_id: :employee_id,
    name: :name,
    phone: :phone,
    email: :email,
    agency: :agency,
    division: :division,
    department: :department,
    unit: :unit,
    date_of_injury_or_illness: :date_of_injury_or_illness,
    how_the_injury_occurred: :what_happened_tell_us_how_the_injury_occurred,
    specific_injury_and_body_part_affected: :what_was_the_injury_or_illness,
    activity_at_time_of_incident: :what_was_the_employee_doing_just_before_the_incident_occurred,
    physician_name: :name_of_physician_or_other_health_care_professional,
    hospitalized_overnight: :was_the_employee_hospitalized_overnight_as_an_inpatient,
    hospital_name: :facility_name,
    hospital_address: :facility_street_address
  }.freeze

  has_one :osha_report

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end

  # An OSHA Report (Form 301) is owed when the safety officer marks the incident
  # as recordable (goes on the 300 Log) or reportable (must also be called in to
  # OSHA). Either answer spawns the same pre-filled 301.
  def osha_report_required?
    osha_recordable == 'Yes' || osha_reportable == 'Yes'
  end

  # Reportable cases carry an 8-hour deadline for the 301 to be filed.
  def osha_reportable?
    osha_reportable == 'Yes'
  end

  # Create a pre-filled OSHA Report from this Safety Report's data.
  # approver_id is the safety officer who flipped osha_recordable or
  # osha_reportable to Yes — they own the resulting OSHA Report.
  def create_osha_report!(approver_id:)
    attrs = OSHA_REPORT_FIELD_MAP.each_with_object({}) do |(source_field, osha_field), hash|
      hash[osha_field] = send(source_field)
    end
    attrs[:approver_id] = approver_id
    attrs[:safety_report_id] = id
    # Reportable cases owe OSHA a filed 301 within 8 hours. The clock starts now
    # rather than at the injury date: this flip is the moment the system learns
    # the case is reportable, so it's the only start the app can honestly act on.
    attrs[:reportable_due_at] = Time.current + OshaReport::REPORTABLE_FILING_WINDOW if osha_reportable?

    create_osha_report(attrs).tap(&:save!)
  end
end
