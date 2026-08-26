# frozen_string_literal: true

# app/models/critical_information_authorization.rb
#
# One incident manager authorized over one site. The Critical Information
# Reporting console is the smallest of the three: a CIR is routed by the
# "Where: Location" field alone, so there is nothing to scope by service type,
# budget unit or org node — only "who covers this site".
#
# Exactly one manager per location, enforced by a unique index.
# CriticalInformationReporting#assigned_manager_id is a single column, so a
# second manager on the same site could never be routed to; the console makes
# you pick instead of silently dropping one.
#
# `location` holds a CriticalInformationLocation name verbatim — the same
# string the form's dropdown submits — so routing is an exact lookup rather
# than the address fuzzy-matching this table replaced.
class CriticalInformationAuthorization < ApplicationRecord
  # Incident managers are General Services Agency staff. The org tables call
  # the agency GSA; employee records carry the four-character personnel-system
  # variant, which is what employees.agency has to be matched on.
  MANAGER_AGENCY_CODE = 'GSAV'

  validates :employee_id, presence: true
  validates :location, presence: true
  validates :location, uniqueness: { message: 'already has an incident manager' }
  validate :location_on_the_form, if: :location_changed?
  # Only checked when the manager changes, so an existing row stays editable
  # (and removable) if someone later transfers out of the agency.
  validate :employee_in_manager_agency, if: :employee_id_changed?

  scope :for_location, ->(location) { where(location: location) }

  def employee
    Employee.find_by(employee_id: employee_id)
  end

  def manager_name
    e = employee
    e ? "#{e.first_name} #{e.last_name}".strip : nil
  end

  # The incident manager covering a site, or nil when nobody does. Exact match
  # first; a normalized comparison catches reports whose location predates a
  # catalogue edit or arrived from somewhere other than the dropdown.
  def self.manager_id_for_location(location)
    return nil if location.blank?

    exact = for_location(location.to_s).pick(:employee_id)
    return exact if exact.present?

    target = normalize(location)
    return nil if target.blank?

    all.find { |row| normalize(row.location) == target }&.employee_id
  end

  # Incident managers eligible to act on a submission, for routing steps that
  # target this console.
  def self.manager_ids_for_submission(submission)
    location = submission.location if submission.respond_to?(:location)
    Array(manager_id_for_location(location)).map(&:to_s)
  end

  # Column => values narrowing inbox rows to the sites these managers cover, or
  # nil when they cover none. The inbox filters submissions in SQL, so it needs
  # the scope rather than the managers.
  def self.inbox_conditions_for(employee_ids)
    locations = where(employee_id: Array(employee_ids)).pluck(:location).compact.uniq
    locations.empty? ? nil : { location: locations }
  end

  # Employees eligible to be named an incident manager: everyone in the General
  # Services Agency.
  def self.manager_candidates
    Employee.where(agency: MANAGER_AGENCY_CODE).order(:last_name, :first_name)
  end

  def self.manager_candidate_ids
    manager_candidates.pluck(:id).map(&:to_s)
  end

  def self.manager_in_agency?(employee_id)
    Employee.where(id: employee_id.to_s, agency: MANAGER_AGENCY_CODE).exists?
  end

  # Case, punctuation and spacing only — no address-word rewriting. The old
  # router guessed at abbreviations to bridge two hand-maintained lists; both
  # sides now come from the same catalogue, so a guess would only reintroduce
  # the mismatches this table exists to remove.
  def self.normalize(location)
    location.to_s.upcase.gsub(/[^A-Z0-9]+/, ' ').strip
  end

  private

  def location_on_the_form
    return if location.blank?
    return if CriticalInformationLocation.exists_named?(location)

    errors.add(:location, 'is not a location on the Critical Information Reporting form')
  end

  def employee_in_manager_agency
    return if employee_id.blank?
    return if self.class.manager_in_agency?(employee_id)

    errors.add(:employee_id, 'is not a General Services Agency employee')
  end
end
