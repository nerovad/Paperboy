# frozen_string_literal: true

# app/controllers/authorized_approver_changes_controller.rb
require 'csv'

# The parking, badges and keys console's change log. Anyone who can see a
# department in the console can read its log; there is nothing here to write.
class AuthorizedApproverChangesController < ApplicationController
  include AuthorizationConsoleDepartments

  # The screen shows the most recent changes; the CSV carries all of them.
  PAGE_LIMIT = 200

  before_action :require_auth_console
  before_action :set_managed_departments

  def index
    readable = department_ids_with('read')
    @department_ids = Array(params[:department_id]).reject(&:blank?) & readable
    scope = AuthorizedApproverChange.where(department_id: @department_ids.presence || readable).newest_first

    respond_to do |format|
      format.html do
        @changes = scope.limit(PAGE_LIMIT).to_a
        @truncated = scope.count > PAGE_LIMIT
        @names = names_for(@changes)
      end
      format.csv do
        changes = scope.to_a
        send_data changes_csv(changes, names_for(changes)),
                  filename: "authorization_changes_#{Date.current}.csv", type: 'text/csv'
      end
    end
  end

  private

  def names_for(changes)
    employee_names_by_id(changes.flat_map { |change| [change.employee_id, change.changed_by] })
  end

  def changes_csv(changes, names)
    CSV.generate do |csv|
      csv << ['When', 'Action', 'Employee ID', 'Employee Name', 'Department ID', 'Changed By ID',
              'Changed By Name', 'Field', 'Before', 'After']
      changes.each do |change|
        change.differences.each do |(heading, before, after)|
          csv << [change.created_at.strftime('%Y-%m-%d %H:%M'), change.action, change.employee_id,
                  names[change.employee_id], change.department_id, change.changed_by,
                  names[change.changed_by], heading, before, after]
        end
      end
    end
  end
end
