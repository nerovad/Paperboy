# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  before_action :require_system_admin

  def index
    @forms = available_forms
  end

  def generate
    form_type = params[:form_type]
    start_date = Date.parse(params[:start_date])
    end_date = Date.parse(params[:end_date])
    format = params[:format]

    if form_type.blank? || start_date.blank? || end_date.blank?
      redirect_to reports_path, alert: "Please fill in all required fields"
      return
    end

    if start_date > end_date
      redirect_to reports_path, alert: "Start date must be before end date"
      return
    end

    # Queue the report generation job
    ReportGenerationJob.perform_later(
      session.dig(:user, "employee_id"),
      form_type,
      start_date.to_s,
      end_date.to_s,
      format
    )

    redirect_to reports_path, notice: "Your report is being generated. You will receive an email when it's ready."
  end

  private

  def require_system_admin
    employee_id = session.dig(:user, "employee_id").to_s
    employee = Employee.find_by(EmployeeID: employee_id)
    
    unless employee&.in_any_group?('System_Admins')
      redirect_to root_path, alert: "You do not have permission to access Reports."
    end
  end

  def available_forms
    FormTemplate.all.order(:name).map do |template|
      {
        name: template.name,
        value: template.class_name.tableize  # Converts "ParkingLotSubmission" → "parking_lot_submissions"
      }
    end
  end
end
