class ParkingLotSubmissionsController < ApplicationController
  def new
    @parking_lot_submission = ParkingLotSubmission.new

    # GSABSS lookups
    @agencies = Agency.all
    @divisions = Division.all
    @departments = Department.all
    @units = Unit.all

    @form_logo = "/assets/images/default-logo.svg"

    @form_pages = [
      {
        title: "Employee Info",
        fields: [
          { name: "name", label: "Name", type: "text", required: true },
          { name: "phone", label: "Phone", type: "text", required: true },
          { name: "employee_id", label: "Employee ID", type: "text", required: true },
          { name: "email", label: "Email", type: "text", required: true }
        ]
      },
      {
        title: "Agency Info",
        fields: [
          { name: "agency", label: "Agency", type: "select", required: true },
          { name: "division", label: "Division", type: "select", required: true },
          { name: "department", label: "Department", type: "select", required: true },
          { name: "unit", label: "Unit", type: "select", required: true }
        ]
      },
      {
        title: "Vehicle Info",
        fields: [
          { name: "make", label: "Make", type: "text", required: true },
          { name: "model", label: "Model", type: "text", required: true },
          { name: "color", label: "Color", type: "text", required: true },
          { name: "year", label: "Year", type: "text", required: true },
          { name: "license_plate", label: "License Plate", type: "text", required: true }
        ]
      },
      {
        title: "Parking Details",
        fields: [
          { name: "parking_lot", label: "Parking Lot", type: "text", required: true },
          { name: "old_permit_number", label: "Old Permit Number", type: "text", required: false }
        ]
      }
    ]
  end

  def create
    @parking_lot_submission = ParkingLotSubmission.new(parking_lot_submission_params)

    if @parking_lot_submission.save
      render :create
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def parking_lot_submission_params
    params.require(:parking_lot_submission).permit(
      :name, :phone, :employee_id, :email, :agency, :division, :department,
      :make, :model, :color, :year, :license_plate, :parking_lot, :old_permit_number
    )
  end
end

