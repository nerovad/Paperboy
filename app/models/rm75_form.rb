class Rm75Form < ApplicationRecord
  include TrackableStatus

enum :status, {
  in_progress: 0,
    step_1_pending: 1,
    approved: 2,
    denied: 3,
    cancelled: 4
}, default: :in_progress

# Normalized status categories for cross-form reporting
STATUS_CATEGORIES = {
  in_progress: :in_review,
    step_1_pending: :in_review,
    approved: :approved,
    denied: :denied,
    cancelled: :cancelled
}.freeze

# Human-readable status labels
STATUS_LABELS = {
  in_progress: "In Progress",
    step_1_pending: "Sent to Supervisor",
    approved: "Approved",
    denied: "Denied",
    cancelled: "Cancelled"
}.freeze

  GARY_HOWARD_ID = '135272'.freeze

  # RM75 → OSHA 301 field mapping
  OSHA301_FIELD_MAP = {
    employee_id:                          :employee_id,
    name:                                 :name,
    phone:                                :phone,
    email:                                :email,
    agency:                               :agency,
    division:                             :division,
    department:                           :department,
    unit:                                 :unit,
    date_of_injury_or_illness:            :date_of_injury_or_illness,
    how_the_injury_occurred:              :what_happened_tell_us_how_the_injury_occurred,
    specific_injury_and_body_part_affected: :what_was_the_injury_or_illness,
    activity_at_time_of_incident:         :what_was_the_employee_doing_just_before_the_incident_occurred,
    physician_name:                       :name_of_physician_or_other_health_care_professional,
    hospitalized_overnight:               :was_the_employee_hospitalized_overnight_as_an_inpatient,
    hospital_name:                        :facility_name,
    hospital_address:                     :facility_street_address
  }.freeze

  has_one :osha301_form

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # For inbox queue display
  def status_label
  self.class.const_defined?(:STATUS_LABELS) ? (self.class::STATUS_LABELS[status&.to_sym] || status&.to_s&.humanize || "Unknown") : (status&.to_s&.humanize || "Unknown")
end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end

  # Create a pre-filled OSHA 301 form from this RM75's data
  def create_osha301!
    attrs = OSHA301_FIELD_MAP.each_with_object({}) do |(rm75_field, osha_field), hash|
      hash[osha_field] = send(rm75_field)
    end
    attrs[:approver_id] = GARY_HOWARD_ID
    attrs[:rm75_form_id] = id

    create_osha301_form!(attrs)
  end
end
