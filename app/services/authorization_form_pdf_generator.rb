# app/services/authorization_form_pdf_generator.rb
require "prawn"

class AuthorizationFormPdfGenerator
  def self.generate(submission)
    logo_path = Rails.root.join("app", "assets", "images", "Ventura_Logo.png")
    
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with logo
      pdf.image(logo_path.to_s, width: 80) if File.exist?(logo_path)
      pdf.move_down 10
      pdf.text "GSA Authorization Form", size: 22, style: :bold, align: :center
      pdf.move_down 20
      
      # Employee Info
      pdf.text "Employee Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Name: #{submission.name}"
      pdf.text "Email: #{submission.email}"
      pdf.text "Phone: #{submission.phone}"
      pdf.text "Employee ID: #{submission.employee_id}"
      pdf.move_down 15
      
      # Agency Information
      pdf.text "Agency Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Agency: #{submission.agency_long_name}"
      pdf.text "Division: #{submission.division_long_name}"
      pdf.text "Department: #{submission.department_long_name}"
      pdf.text "Unit: #{submission.unit_display}"
      pdf.move_down 15
      
      # Authorization Information
      pdf.text "Authorization Information", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Service Type: #{format_service_type(submission.service_type)}"
      
      if submission.service_type == "K" && submission.key_type.present?
        pdf.text "Type of Service: #{format_key_type(submission.key_type)}"
      end
      
      pdf.text "Budget Units: #{format_budget_units(submission.budget_units)}"
      pdf.move_down 15
      
      # Approval Information (if approved)
      if submission.approved_at.present?
        pdf.text "Approval Information", size: 14, style: :bold
        pdf.move_down 5
        pdf.text "Department Head Approved By: #{submission.approved_by}"
        pdf.text "Approved At: #{submission.approved_at.strftime('%B %d, %Y at %I:%M %p')}"
        
        if submission.delegated_approved_at.present?
          pdf.text "Final Approved By: #{submission.delegated_approved_by}"
          pdf.text "Final Approved At: #{submission.delegated_approved_at.strftime('%B %d, %Y at %I:%M %p')}"
        end
        pdf.move_down 15
      end
      
      pdf.move_down 25
      pdf.text "Submitted on: #{submission.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end
  
  private
  
  def self.format_service_type(type)
    case type
    when "P" then "Parking Permit (P)"
    when "E" then "Employee Identification Badges (E)"
    when "V" then "Volunteer ID Badges (V)"
    when "C" then "Vendor ID Badges (C)"
    when "K" then "Facility Keys and Security Access (K)"
    else type
    end
  end
  
  def self.format_key_type(type)
    case type
    when "1" then "1 = Master Keys"
    when "2" then "2 = Access Cards"
    when "3" then "3 = Site Keys"
    when "4" then "4 = Area / Room Keys"
    when "5" then "5 = Perimeter Fence Gates"
    when "6" then "6 = Equipment Closet Keys"
    when "7" then "7 = File/Desk/Storage Cabinet Keys"
    else type
    end
  end
  
  def self.format_budget_units(units)
    case units
    when "A" then "A = All Budget Units - All Locations"
    when "B" then "B = Multiple Budget Units - All Locations"
    when "C" then "C = Multiple Budget Units - Multiple Locations"
    when "D" then "D = Single Budget Unit - Multiple Locations"
    when "E" then "E = Single Budget Unit - Single Location"
    else units
    end
  end
end
