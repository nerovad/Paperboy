# app/controllers/inbox_controller.rb
class InboxController < ApplicationController
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

    # Critical Information Reporting forms assigned to this manager
    @submissions += CriticalInformationReporting.where(assigned_manager_id: employee_id, status: 0)

    # Collect unique values for filter dropdowns before filtering
    @filter_options = collect_filter_options(@submissions)

    # Apply filters
    @submissions = apply_filters(@submissions)

    # Apply sorting
    sort_by = params[:sort_by] || 'created_at'
    sort_direction = params[:sort_direction] || 'desc'

    @submissions = sort_submissions(@submissions, sort_by, sort_direction)

    # Load employees for reassignment dropdown
    @employees = Employee.order(:Last_Name, :First_Name)
  end

  private

  def collect_filter_options(submissions)
    {
      form_types: submissions.map { |s| s.class.name.demodulize.titleize }.uniq.sort,
      names: submissions.map(&:name).compact.uniq.sort_by(&:downcase),
      units: submissions.map { |s| s.try(:unit) }.compact.uniq.sort_by(&:downcase),
      emails: submissions.map(&:email).compact.uniq.sort_by(&:downcase),
      statuses: submissions.map { |s| s.status_label.to_s.tr('_', ' ').titleize }.compact.uniq.sort
    }
  end

  def apply_filters(submissions)
    filtered = submissions

    if params[:filter_form_type].present?
      filtered = filtered.select { |s| s.class.name.demodulize.titleize == params[:filter_form_type] }
    end

    if params[:filter_name].present?
      filtered = filtered.select { |s| s.name == params[:filter_name] }
    end

    if params[:filter_unit].present?
      filtered = filtered.select { |s| s.try(:unit) == params[:filter_unit] }
    end

    if params[:filter_email].present?
      filtered = filtered.select { |s| s.email == params[:filter_email] }
    end

    if params[:filter_status].present?
      filtered = filtered.select { |s| s.status_label.to_s.tr('_', ' ').titleize == params[:filter_status] }
    end

    if params[:filter_date_from].present?
      from_date = Date.parse(params[:filter_date_from]).beginning_of_day
      filtered = filtered.select { |s| s.created_at >= from_date }
    end

    if params[:filter_date_to].present?
      to_date = Date.parse(params[:filter_date_to]).end_of_day
      filtered = filtered.select { |s| s.created_at <= to_date }
    end

    filtered
  end

  def sort_submissions(submissions, sort_by, direction)
    sorted = case sort_by
    when 'form_type'
      submissions.sort_by { |s| s.class.name.demodulize.titleize }
    when 'name'
      submissions.sort_by { |s| s.name.to_s.downcase }
    when 'unit'
      submissions.sort_by { |s| (s.try(:unit) || '').to_s.downcase }
    when 'email'
      submissions.sort_by { |s| s.email.to_s.downcase }
    when 'status'
      submissions.sort_by { |s| s.status_label.to_s.downcase }
    else # 'created_at' or any other default
      submissions.sort_by(&:created_at)
    end

    direction == 'desc' ? sorted.reverse : sorted
  end

end
