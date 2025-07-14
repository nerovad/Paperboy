require "prawn"

class ProbationTransferPdfGenerator
  def self.generate(request)
    logo_path = Rails.root.join("app", "assets", "images", "Ventura_Logo.png")

    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with logo
      if File.exist?(logo_path)
        pdf.image logo_path.to_s, width: 80
      end

      pdf.move_down 10
      pdf.text "Probation Transfer Request", size: 22, style: :bold, align: :center
      pdf.move_down 20

      # Employee Info
      pdf.text "Employee Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Name: #{request.name}"
      pdf.text "Email: #{request.email}"
      pdf.text "Phone: #{request.phone}"
      pdf.text "Employee ID: #{request.employee_id}"

      pdf.move_down 15
      pdf.text "Agency Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Agency: #{request.agency}"
      pdf.text "Division: #{request.division}"
      pdf.text "Department: #{request.department}"
      pdf.text "Unit: #{request.unit}"
      pdf.text "Work Location: #{request.work_location}"

      pdf.move_down 15
      pdf.text "Transfer Request Details", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Current Assignment Date: #{request.current_assignment_date.strftime('%B %d, %Y') if request.current_assignment_date.present?}"
      pdf.text "Desired Transfer Destination(s): #{request.desired_transfer_destination}"

      pdf.move_down 25
      pdf.text "Submitted on: #{request.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end
end
