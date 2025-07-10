require "prawn"

class ParkingLotPdfGenerator
  def self.generate(submission)
    logo_path = Rails.root.join("app", "assets", "images", "Ventura_Logo.png")

    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with logo
      if File.exist?(logo_path)
        pdf.image logo_path.to_s, width: 80
      end

      pdf.move_down 10
      pdf.text "Parking Lot Submission", size: 22, style: :bold, align: :center
      pdf.move_down 20

      # Employee Info Section
      pdf.text "Employee Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Name: #{submission.name}"
      pdf.text "Email: #{submission.email}"
      pdf.text "Phone: #{submission.phone}"
      pdf.text "Employee ID: #{submission.employee_id}"

      pdf.move_down 15
      pdf.text "Agency Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Agency: #{submission.agency}"
      pdf.text "Division: #{submission.division}"
      pdf.text "Department: #{submission.department}"
      pdf.text "Unit: #{submission.unit}"

      pdf.move_down 15
      pdf.text "Vehicle Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Make: #{submission.make}"
      pdf.text "Model: #{submission.model}"
      pdf.text "Color: #{submission.color}"
      pdf.text "Year: #{submission.year}"
      pdf.text "License Plate: #{submission.license_plate}"

      pdf.move_down 15
      pdf.text "Parking Details", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Parking Lot: #{submission.parking_lot}"
      pdf.text "Old Permit Number: #{submission.old_permit_number.presence || 'N/A'}"

      pdf.move_down 25
      pdf.text "Submitted on: #{submission.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end
end
