# frozen_string_literal: true

class RestoreOshaReportingApprovalRouting < ActiveRecord::Migration[8.0]
  def up
    template = FormTemplate.find_by(class_name: 'OshaReport')
    return unless template

    # Ensure 'Denied' terminal status exists so the approval validation passes
    # and so the deny button can flip OshaReport.status to :denied.
    unless template.statuses.exists?(category: 'denied')
      max_position = template.statuses.maximum(:position).to_i
      template.statuses.create!(
        name: 'Denied',
        key: 'denied',
        category: 'denied',
        position: max_position + 1,
        is_initial: false,
        is_end: true,
        auto_generated: false
      )
    end

    # Flip submission_type back to 'approval' so the inbox query picks up
    # OshaReports whose approver_id is set (which the SafetyReport ->
    # create_osha_report! chain already does for Gary).
    template.update_columns(submission_type: 'approval')
  end

  def down
    template = FormTemplate.find_by(class_name: 'OshaReport')
    return unless template

    template.update_columns(submission_type: 'database')
    template.statuses.where(category: 'denied', auto_generated: false).destroy_all
  end
end
