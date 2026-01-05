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
  end

end
