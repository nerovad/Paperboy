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
# `location` holds a CriticalInformationLocation::ALL value verbatim — the same
# string the form's dropdown submits — so routing is an exact lookup rather
# than the address fuzzy-matching this table replaced.
class CriticalInformationAuthorization < ApplicationRecord
  # Only members of this group can be named an incident manager. Mirrors the
  # Safety console's officer group: holding a CIR authorization should follow
  # from being on the incident team, not from any admin having a free hand.
  MANAGER_GROUP_NAME = 'Critical_Incident_Managers'

  validates :employee_id, presence: true
  validates :location, presence: true
  validates :location, uniqueness: { message: 'already has an incident manager' }
  validates :location, inclusion: {
    in: -> { CriticalInformationLocation::ALL },
    message: 'is not a location on the Critical Information Reporting form'
  }
  # Only checked when the manager changes, so an existing row stays editable
  # (and removable) if someone later leaves the group.
  validate :employee_in_manager_group, if: :employee_id_changed?

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

  # Employee ids eligible to be named an incident manager. Groups and
  # Employee_Groups live in the Paperboy DB while Employees lives in GSABSS, so
  # this can't be a join — the ids come back first and are looked up separately.
  def self.manager_candidate_ids
    group_id = Group.find_by(Group_Name: MANAGER_GROUP_NAME)&.GroupID
    return [] if group_id.blank?

    EmployeeGroup.where(GroupID: group_id).pluck(:EmployeeID).map(&:to_s).uniq
  end

  # Case, punctuation and spacing only — no address-word rewriting. The old
  # router guessed at abbreviations to bridge two hand-maintained lists; both
  # sides now come from the same catalogue, so a guess would only reintroduce
  # the mismatches this table exists to remove.
  def self.normalize(location)
    location.to_s.upcase.gsub(/[^A-Z0-9]+/, ' ').strip
  end

  private

  def employee_in_manager_group
    return if employee_id.blank?

    candidates = self.class.manager_candidate_ids
    return if candidates.empty? # group missing or empty — don't block the console
    return if candidates.include?(employee_id.to_s)

    errors.add(:employee_id, "is not a member of the #{MANAGER_GROUP_NAME} group")
  end
end
