# frozen_string_literal: true

# app/controllers/authorization_coverage_controller.rb
#
# The parking, badges and keys console's coverage screen: the budget units in
# each department a viewer can see that have no approver for a service type.
# A manager finds the gap here instead of from an employee whose request was
# turned away.
class AuthorizationCoverageController < ApplicationController
  include AuthorizationConsoleDepartments

  before_action :require_auth_console
  before_action :set_managed_departments

  def index
    readable = department_ids_with('read')
    @department_ids = Array(params[:department_id]).reject(&:blank?) & readable
    shown = @department_ids.presence || readable

    @departments = @managed_departments.select { |department| shown.include?(department.department_id.to_s) }
    @gaps_by_department = AuthorizedApprover.coverage_gaps(units_by_department(shown))
  end
end
