# app/controllers/inbox_controller.rb
class InboxController < ApplicationController
  def queue
    employee = session[:user]
    return @submissions = [] unless employee.present? && employee["employee_id"].present?

    employee_id = employee["employee_id"].to_s

    @submissions = []

    @submissions += ParkingLotSubmission.where(supervisor_id: employee_id, status: 0)
    @submissions += ProbationTransferRequest.where(supervisor_id: employee_id, status: 0, canceled_at: nil)

    @submissions.sort_by!(&:created_at).reverse!
  end
end
