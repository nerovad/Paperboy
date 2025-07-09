# app/services/parking_lot_pdf_generator.rb
class ParkingLotPdfGenerator
  def self.generate(submission)
    Prawn::Document.new do |pdf|
      pdf.text "Parking Lot Submission", size: 20, style: :bold
      pdf.move_down 20

      pdf.text "Name: #{submission.name}"
      pdf.text "Email: #{submission.email}"
      pdf.text "Phone: #{submission.phone}"
      pdf.text "Employee ID: #{submission.employee_id}"
      pdf.text "Agency: #{submission.agency}"
      pdf.text "Division: #{submission.division}"
      pdf.text "Department: #{submission.department}"
      pdf.text "Unit: #{submission.unit}"
      pdf.move_down 10

      pdf.text "Vehicle: #{submission.year} #{submission.make} #{submission.model}, Color: #{submission.color}"
      pdf.text "License Plate: #{submission.license_plate}"
      pdf.text "Parking Lot: #{submission.parking_lot}"
      pdf.text "Old Permit Number: #{submission.old_permit_number}"
    end.render
  end
end
