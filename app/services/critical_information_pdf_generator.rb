require "prawn"

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
      pdf.text "Staff Involved: #{cir.staff_involved}"
      pdf.text "Incident Manager: #{cir.incident_manager}"
      pdf.text "Reported By: #{cir.reported_by}"
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

      pdf.move_down 25
      pdf.text "Submitted on: #{cir.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end
end
