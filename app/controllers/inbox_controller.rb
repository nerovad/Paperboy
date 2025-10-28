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
    
    @submissions.sort_by!(&:created_at).reverse!
    
    # Load department employees for parking lot submissions needing dept head approval
    @department_employees = {}
    parking_submissions_needing_delegation = @submissions.select do |s|
      s.is_a?(ParkingLotSubmission) && s.supervisor_id == employee_id && s.submitted?
    end
    
    submissions_needing_delegation = @submissions.select do |s|
      s.is_a?(ParkingLotSubmission) && s.supervisor_id == employee_id && s.submitted?
    end
  end

  private

  # app/controllers/inbox_controller.rb

    def fetch_department_employees(department_id)
      return [] if department_id.blank?
      
      result = ActiveRecord::Base.connection.exec_query(<<-SQL.squish)
        SELECT EmployeeID, First_Name, Last_Name, EE_Email
        FROM [GSABSS].[dbo].[Employees] e
        INNER JOIN [GSABSS].[dbo].[Units] u ON e.Unit = u.unit_id
        WHERE u.department_id = '#{department_id}'
        ORDER BY Last_Name, First_Name
      SQL
      
      result.map do |row|
        {
          id: row["EmployeeID"],
          name: "#{row["First_Name"]} #{row["Last_Name"]}",
          email: row["EE_Email"]
        }
      end
    end
  end
