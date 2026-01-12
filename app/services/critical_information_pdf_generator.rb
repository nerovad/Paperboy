require "prawn"
require "tempfile"

class CriticalInformationPdfGenerator
  def self.generate(cir)
    logo_path = Rails.root.join("app", "assets", "images", "Ventura_Logo.png")

    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with logo
      if File.exist?(logo_path)
        pdf.image logo_path.to_s, width: 80
      end

      pdf.move_down 10
      pdf.text "Critical Information Report", size: 22, style: :bold, align: :center
      pdf.move_down 20

      # Employee Info
      pdf.text "Employee Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Name: #{cir.name}"
      pdf.text "Email: #{cir.email}"
      pdf.text "Phone: #{cir.phone}"
      pdf.text "Employee ID: #{cir.employee_id}"

      pdf.move_down 15
      pdf.text "Agency Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Agency: #{cir.agency}"
      pdf.text "Division: #{cir.division}"
      pdf.text "Department: #{cir.department}"
      pdf.text "Unit: #{cir.unit}"

      pdf.move_down 15
      pdf.text "Incident Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Incident Type: #{cir.incident_type}"
      pdf.text "Location: #{cir.location}"
      pdf.text "Impact Started: #{cir.impact_started.strftime('%B %d, %Y at %I:%M %p') if cir.impact_started.present?}"
      pdf.move_down 10
      pdf.text "Incident Details:", style: :bold
      pdf.text cir.incident_details.to_s, indent_paragraphs: 20
      pdf.move_down 10
      pdf.text "Cause:", style: :bold
      pdf.text cir.cause.to_s, indent_paragraphs: 20

      pdf.move_down 15
      pdf.text "Staff & Management", size: 14, style: :bold
      pdf.move_down 5

      # Handle comma-separated employee IDs for staff_involved
      if cir.staff_involved.present?
        staff_ids = cir.staff_involved.split(",").map(&:strip)
        staff_names = staff_ids.map do |employee_id|
          employee = Employee.find_by(EmployeeID: employee_id)
          employee ? "#{employee['First_Name']} #{employee['Last_Name']}" : employee_id
        end
        pdf.text "Staff Involved: #{staff_names.join(', ')}"
      else
        pdf.text "Staff Involved: None"
      end

      pdf.text "Assigned Manager: #{cir.assigned_manager_name}"

      pdf.move_down 15
      pdf.text "Status & Impact", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Status: #{cir.status_label}"
      pdf.text "Urgency: #{cir.urgency}"
      pdf.text "Impact: #{cir.impact}"
      pdf.text "Impacted Customers: #{cir.impacted_customers}"
      pdf.move_down 10
      pdf.text "Next Steps:", style: :bold
      pdf.text cir.next_steps.to_s, indent_paragraphs: 20

      if cir.actual_completion_date.present?
        pdf.move_down 10
        pdf.text "Actual Completion Date: #{cir.actual_completion_date.strftime('%B %d, %Y at %I:%M %p')}"
      end

      # Include media attachment if present
      if cir.media.attached?
        pdf.move_down 15
        pdf.text "Attached Media", size: 14, style: :bold
        pdf.move_down 5

        if cir.media.content_type.start_with?('image/')
          # Embed image in PDF
          begin
            # Download the image to a temporary file
            tempfile = Tempfile.new(['media', File.extname(cir.media.filename.to_s)])
            tempfile.binmode
            tempfile.write(cir.media.download)
            tempfile.rewind

            # Use Prawn's fit option to automatically scale the image
            max_width = pdf.bounds.width
            max_height = 300

            pdf.image tempfile.path, fit: [max_width, max_height], position: :left
            pdf.move_down 5
            pdf.text "Filename: #{cir.media.filename}", size: 9, style: :italic

            tempfile.close
            tempfile.unlink
          rescue => e
            pdf.text "Error loading image: #{e.message}", size: 9, color: 'FF0000'
          end
        elsif cir.media.content_type == 'application/pdf'
          pdf.text "PDF Document: #{cir.media.filename}", size: 10
          pdf.text "(See separate attachment)", size: 9, style: :italic, color: '666666'
        else
          pdf.text "File: #{cir.media.filename}", size: 10
          pdf.text "Type: #{cir.media.content_type}", size: 9, style: :italic
        end
      end

      pdf.move_down 25
      pdf.text "Submitted on: #{cir.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end
end
