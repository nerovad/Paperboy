# frozen_string_literal: true

# app/models/safety_report_authorization.rb
#
# One safety officer authorized over one HCA org node. The Safety Reporting
# console is deliberately much smaller than the parking/badge/key console
# (AuthorizedApprover): there is nothing to scope by service type, budget unit
# or building — only "who covers this org node".
#
# `division_id` is a GSABSS `divisions.division_id` under agency HCA. HCA calls
# that level a *department*, so every user-facing label goes through OrgLabels;
# the column keeps the name the database uses.
class SafetyReportAuthorization < ApplicationRecord
  AGENCY_ID = 'HCA'

  # Only members of this group can be named a safety officer. The console used
  # to offer every HCA employee, which made it easy to authorize someone who
  # isn't on the safety team at all.
  OFFICER_GROUP_NAME = 'HCA_Safety_Officers'

  validates :employee_id, presence: true
  validates :division_id, presence: true
  validates :employee_id, uniqueness: {
    scope: :division_id,
    message: 'is already an authorized safety officer for this department'
  }
  # Only checked when the officer changes, so an existing row stays editable
  # (and removable) if someone later leaves the group.
  validate :employee_in_officer_group, if: :employee_id_changed?

  scope :for_division, ->(division_id) { where(division_id: division_id) }

  def employee
    Employee.find_by(employee_id: employee_id)
  end

  def division
    Division.find_by(agency_id: AGENCY_ID, division_id: division_id)
  end

  # Label for the org node this authorization covers, in HCA's vocabulary.
  def division_label
    "#{division_id} - #{division&.long_name}".sub(/ - \z/, '')
  end

  # Every safety officer covering the given HCA org node.
  def self.officer_ids_for_division(division_id)
    for_division(division_id).pluck(:employee_id).uniq
  end

  # Safety officers eligible to act on a submission, for routing steps that
  # target this console.
  def self.officer_ids_for_submission(submission)
    division_id = submission_division_id(submission)
    return [] if division_id.blank?

    officer_ids_for_division(division_id).map(&:to_s)
  end

  # Employee ids eligible to be named a safety officer. Groups and
  # Employee_Groups live in the Paperboy DB while Employees lives in GSABSS, so
  # this can't be a join — the ids come back first and are looked up separately.
  def self.officer_candidate_ids
    group_id = Group.find_by(Group_Name: OFFICER_GROUP_NAME)&.GroupID
    return [] if group_id.blank?

    EmployeeGroup.where(GroupID: group_id).pluck(:EmployeeID).map(&:to_s).uniq
  end

  # The org node a submission sits under. Safety Reporting captures the
  # division on the submission itself via the org cascade; fall back to the
  # submitter's own chain for forms that don't carry one.
  def self.submission_division_id(submission)
    direct = submission.division if submission.respond_to?(:division)
    return direct if direct.present?

    employee_id = submission.employee_id if submission.respond_to?(:employee_id)
    return nil if employee_id.blank?

    Unit.resolve_for_employee(Submitter.resolve(employee_id))&.division_id
  end
  private_class_method :submission_division_id

  private

  def employee_in_officer_group
    return if employee_id.blank?

    candidates = self.class.officer_candidate_ids
    return if candidates.empty? # group missing or empty — don't block the console
    return if candidates.include?(employee_id.to_s)

    errors.add(:employee_id, "is not a member of the #{OFFICER_GROUP_NAME} group")
  end
end
