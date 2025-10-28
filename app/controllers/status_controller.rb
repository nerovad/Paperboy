# app/controllers/status_controller.rb
class StatusController < ApplicationController
  def index
    employee_id = session[:user]["employee_id"].to_s

    @status_items = []

    @status_items += ParkingLotSubmission.for_employee(employee_id).map do |f|
      {
        type: "Parking Lot",
        title: "Parking Permit ##{f.id}",
        status: f.status_label,
        submitted_at: f.created_at,
        updated_at: f.updated_at,
        path: parking_lot_submission_path(f)
      }
    end

    @status_items += ProbationTransferRequest.for_employee(employee_id).map do |f|
      {
        type: "Probation Transfer",
        title: "Transfer Request ##{f.id}",
        status: f.status_label,
        submitted_at: f.created_at,
        updated_at: f.updated_at,
        path: probation_transfer_request_path(f)
      }
    end

    @status_items.sort_by! { |i| i[:updated_at] }.reverse!
  end
end
