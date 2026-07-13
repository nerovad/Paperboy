# frozen_string_literal: true

# Resolves a form submitter from the integer id stored on a submission
# (`employee_id`). Employees (GSABSS) and Contractors (Paperboy) share one id
# space — contractor ids are seeded at 1,000,000,000 so they never collide with
# Employee ids — which is what lets a submission reference its submitter as a
# single integer without a type discriminator.
#
# Use this anywhere the workflow/prefill code needs the *submitter*. Approvers
# (supervisors, department heads, group/authorization approvers) are always
# Employees and are resolved directly, not through here.
module Submitter
  def self.resolve(employee_id)
    return nil if employee_id.blank?

    Employee.find_by(employee_id: employee_id) || Contractor.find_by(id: employee_id)
  end
end
