require 'csv'

class OshaLogsController < ApplicationController
  before_action :require_osha_log_access

  def index
    @year = (params[:year].presence || Date.current.year).to_i
    @available_years = years_with_data
    @available_years << @year unless @available_years.include?(@year)
    @available_years.sort!.reverse!

    @rows = build_log_rows(@year)

    respond_to do |format|
      format.html
      format.csv do
        send_data csv_for(@rows, @year),
                  filename: "osha_300_log_#{@year}.csv",
                  type: 'text/csv'
      end
    end
  end

  private

  def years_with_data
    OshaReport
      .where(status: :approved)
      .where.not(date_of_injury_or_illness: nil)
      .pluck(:date_of_injury_or_illness)
      .map(&:year)
      .uniq
  end

  def build_log_rows(year)
    range = Date.new(year, 1, 1)..Date.new(year, 12, 31)

    reports = OshaReport
              .where(status: :approved)
              .where(date_of_injury_or_illness: range)
              .order(:date_of_injury_or_illness, :id)
              .to_a

    return [] if reports.empty?

    employee_ids = reports.map { |r| r.employee_id.to_s }.reject(&:blank?).uniq
    employees_by_id = Employee.where(employee_id: employee_ids).index_by { |e| e.employee_id.to_s }

    safety_ids = reports.map(&:safety_report_id).compact.uniq
    safety_by_id = SafetyReport.where(id: safety_ids).index_by(&:id)

    reports.each_with_index.map do |r, idx|
      employee = employees_by_id[r.employee_id.to_s]
      safety   = safety_by_id[r.safety_report_id]

      {
        case_number: r.case_number_from_the_log.presence || (idx + 1).to_s,
        employee_name: r.name,
        job_title: employee&.job_title,
        date_of_injury: r.date_of_injury_or_illness,
        activity: r.what_was_the_employee_doing_just_before_the_incident_occurred,
        description: r.what_was_the_injury_or_illness,
        died: r.did_employee_die.to_s.casecmp('yes').zero?,
        days_away: compute_days_away(safety),
        report_id: r.id
      }
    end
  end

  # OSHA caps day counts at 180 per case
  def compute_days_away(safety_report)
    return nil unless safety_report

    last_worked = safety_report.date_last_worked
    return nil if last_worked.blank?

    end_date = safety_report.date_returned_to_work.presence || Date.current
    days = (end_date - last_worked).to_i
    [[days, 0].max, 180].min
  end

  def csv_for(rows, year)
    CSV.generate do |csv|
      csv << ["OSHA Form 300 - Log of Work-Related Injuries and Illnesses (#{year})"]
      csv << []
      csv << [
        'Case #', 'Employee Name', 'Job Title', 'Date of Injury',
        'Activity at Time of Incident', 'Description of Injury/Illness',
        'Death?', 'Days Away from Work'
      ]
      rows.each do |row|
        csv << [
          row[:case_number],
          row[:employee_name],
          row[:job_title],
          row[:date_of_injury]&.strftime('%Y-%m-%d'),
          row[:activity],
          row[:description],
          row[:died] ? 'Yes' : 'No',
          row[:days_away]
        ]
      end
    end
  end

  def require_osha_log_access
    return if current_user_group_names.include?('system_admins')
    return if current_user_dropdown_permissions.include?('osha_log')

    redirect_to root_path, alert: 'Access denied.'
  end
end
