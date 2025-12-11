# app/controllers/scheduled_reports_controller.rb
class ScheduledReportsController < ApplicationController
  before_action :require_system_admin
  before_action :set_scheduled_report
  
  def toggle
    @scheduled_report.update(enabled: !@scheduled_report.enabled)
    
    status = @scheduled_report.enabled? ? 'enabled' : 'paused'
    redirect_to reports_path, notice: "Scheduled report #{status}."
  end
  
  def destroy
    @scheduled_report.destroy
    redirect_to reports_path, notice: "Scheduled report deleted successfully."
  end
  
  private
  
  def set_scheduled_report
    employee_id = session.dig(:user, "employee_id")
    @scheduled_report = ScheduledReport.for_employee(employee_id).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to reports_path, alert: "Scheduled report not found."
  end
  
  def require_system_admin
    employee_id = session.dig(:user, "employee_id").to_s
    employee = Employee.find_by(EmployeeID: employee_id)
    
    unless employee&.in_any_group?('System_Admins')
      redirect_to root_path, alert: "You do not have permission to access Scheduled Reports."
    end
  end
end
