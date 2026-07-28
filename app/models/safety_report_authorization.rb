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

  validates :employee_id, presence: true
  validates :division_id, presence: true
  validates :employee_id, uniqueness: {
    scope: :division_id,
    message: 'is already an authorized safety officer for this department'
  }

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
end
