require "prawn"

class ParkingLotPdfGenerator
  def self.generate(submission)
    logo_path = Rails.root.join("app", "assets", "images", "Ventura_Logo.png")

    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with logo
      pdf.image(logo_path.to_s, width: 80) if File.exist?(logo_path)

      pdf.move_down 10
      pdf.text "Parking Lot Submission", size: 22, style: :bold, align: :center
      pdf.move_down 20

      # Employee Info
      pdf.text "Employee Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Name: #{submission.name}"
      pdf.text "Email: #{submission.email}"
      pdf.text "Phone: #{submission.phone}"
      pdf.text "Employee ID: #{submission.employee_id}"

      pdf.move_down 15
      pdf.text "Agency Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Agency: #{submission.agency_long_name}"
      pdf.text "Division: #{submission.division_long_name}"
      pdf.text "Department: #{submission.department_long_name}"
      pdf.text "Unit: #{submission.unit_display}"  # => "1802 - Probation Services"

      pdf.move_down 15
      pdf.text "Vehicle Information", size: 14, style: :bold
      pdf.move_down 5

      if submission.parking_lot_vehicles.any?
        submission.parking_lot_vehicles.each_with_index do |vehicle, index|
          pdf.text "Vehicle ##{index + 1}", style: :bold
          pdf.text "Make: #{vehicle.make}"
          pdf.text "Model: #{vehicle.model}"
          pdf.text "Color: #{vehicle.color}"
          pdf.text "Year: #{vehicle.year}"
          pdf.text "License Plate: #{vehicle.license_plate}"
          pdf.text "Parking Lot: #{vehicle.display_parking_lot}"
          pdf.move_down 10
        end
      else
        pdf.text "No vehicle information provided."
      end

      pdf.move_down 25
      pdf.text "Submitted on: #{submission.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end
end
