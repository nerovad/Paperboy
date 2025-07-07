class ParkingLotController < ApplicationController
  def index
    @form_logo = "/assets/ParkingLot_Logo_020525.svg"

    @form_pages = [
      {
        title: "Employee Information",
        fields: [
          { name: "employee_id", label: "Employee ID", type: "text", required: true },
          { name: "employee_title", label: "Employee Title", type: "text" },
          { name: "employee_email", label: "Employee E-mail", type: "text" },
          { name: "agency", label: "Agency", type: "select", options: ["Select...", "Public Works", "Health Services", "Finance", "IT"] },
          { name: "division", label: "Division", type: "select", options: ["Select...", "Engineering", "Operations", "Human Resources", "Legal"] },
          { name: "department", label: "Department", type: "select", options: ["Select...", "Payroll", "Infrastructure", "Customer Support", "Security"] }
        ]
      },
      {
        title: "Vehicle Information",
        fields: [
          { name: "license_plate", label: "License Plate", type: "text" },
          { name: "model", label: "Vehicle Model", type: "text" },
          { name: "year", label: "Year", type: "select", options: (1980..Time.now.year).to_a.reverse }
        ]
      },
      {
        title: "Parking Lot Details",
        fields: [
          { name: "lot_number", label: "Lot Number", type: "text" },
          { name: "location", label: "Location", type: "text" },
          { name: "permit_type", label: "Permit Type", type: "select", options: ["Temporary", "Permanent"] }
        ]
      }
    ]
  end
end

