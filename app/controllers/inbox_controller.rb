# app/controllers/inbox_controller.rb
class InboxController < ApplicationController
  include Filterable

  def queue
    employee = session[:user]
    return @submissions = [] unless employee.present? && employee["employee_id"].present?

    employee_id = employee["employee_id"].to_s
    @submissions = []

    # Parking Lot Submissions where employee is either:
    # 1. Supervisor (Dept Head) and status = 0 (submitted)
    # 2. Delegated Approver and status = 1 (pending_delegated_approval)
    @submissions += ParkingLotSubmission.where(supervisor_id: employee_id, status: 0)
    @submissions += ParkingLotSubmission.where(delegated_approver_id: employee_id, status: 1)

    # Probation Transfer Requests (unchanged)
    @submissions += ProbationTransferRequest.where(supervisor_id: employee_id, status: 0, canceled_at: nil)

    # Critical Information Reporting forms assigned to this manager (all statuses stay in inbox)
    @submissions += CriticalInformationReporting.where(assigned_manager_id: employee_id)

    # Collect unique values for filter dropdowns before filtering
    @filter_options = collect_filter_options(@submissions, inbox_field_mappings)

    # Apply filters
    @submissions = apply_filters(@submissions,
      filter_configs: inbox_filter_configs,
      date_filters: inbox_date_filters
    )

    # Apply sorting
    sort_by = params[:sort_by] || 'created_at'
    sort_direction = params[:sort_direction] || 'desc'

    @submissions = sort_collection(@submissions, sort_by, sort_direction, inbox_sort_configs)

    # Load employees for reassignment dropdown
    @employees = Employee.order(:Last_Name, :First_Name)
  end

  private

  def inbox_field_mappings
    {
      form_types: ->(s) { s.class.name.demodulize.titleize },
      names: ->(s) { s.name },
      units: ->(s) { s.try(:unit) },
      emails: ->(s) { s.email },
      statuses: ->(s) { s.status_label.to_s.tr('_', ' ').titleize }
    }
  end

  def inbox_filter_configs
    [
      { param: :filter_form_type, extractor: ->(s) { s.class.name.demodulize.titleize } },
      { param: :filter_name, extractor: ->(s) { s.name } },
      { param: :filter_unit, extractor: ->(s) { s.try(:unit) } },
      { param: :filter_email, extractor: ->(s) { s.email } },
      { param: :filter_status, extractor: ->(s) { s.status_label.to_s.tr('_', ' ').titleize } }
    ]
  end

  def inbox_date_filters
    [
      { param: :filter_date_from, extractor: ->(s) { s.created_at }, comparison: :from },
      { param: :filter_date_to, extractor: ->(s) { s.created_at }, comparison: :to }
    ]
  end

  def inbox_sort_configs
    {
      'form_type' => ->(s) { s.class.name.demodulize.titleize },
      'name' => ->(s) { s.name.to_s },
      'unit' => ->(s) { (s.try(:unit) || '').to_s },
      'email' => ->(s) { s.email.to_s },
      'status' => ->(s) { s.status_label.to_s },
      'created_at' => ->(s) { s.created_at.to_s }
    }
  end

end
