require "prawn"

class WorkScheduleOrLocationUpdatePdfGenerator
  def self.generate(submission)
    logo_path = Rails.root.join("app", "assets", "images", "Ventura_Logo.png")

    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header with logo
      pdf.image(logo_path.to_s, width: 80) if File.exist?(logo_path)

      pdf.move_down 10
      pdf.text "Work Schedule or Location Update", size: 22, style: :bold, align: :center
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
      pdf.text "Agency: #{lookup_agency_name(submission.agency)}"
      pdf.text "Division: #{lookup_division_name(submission.division)}"
      pdf.text "Department: #{lookup_department_name(submission.department)}"
      pdf.text "Unit: #{lookup_unit_name(submission.unit)}"

      pdf.move_down 15
      pdf.text "Request Details", size: 14, style: :bold
      pdf.move_down 5
      pdf.text "Requested By: #{submission.try(:requested_by)}" if submission.respond_to?(:requested_by)
      pdf.text "Type of Change: #{submission.try(:type_of_change)}" if submission.respond_to?(:type_of_change)

      if submission.respond_to?(:present_schedule) && submission.present_schedule.present?
        pdf.move_down 10
        pdf.text "Schedule Change", size: 12, style: :bold
        pdf.text "Present Schedule: #{submission.present_schedule}"
        pdf.text "Other Schedule: #{submission.try(:other_schedule)}" if submission.try(:other_schedule).present?
        pdf.text "Proposed Schedule: #{submission.try(:proposed_schedule)}" if submission.try(:proposed_schedule).present?
        pdf.text "Other Proposed Schedule: #{submission.try(:other_proposed_schedule)}" if submission.try(:other_proposed_schedule).present?
      end

      if submission.respond_to?(:present_location) && submission.present_location.present?
        pdf.move_down 10
        pdf.text "Location Change", size: 12, style: :bold
        pdf.text "Present Location: #{submission.present_location}"
        pdf.text "Probation Cleared: #{submission.try(:probation_cleared)}" if submission.try(:probation_cleared).present?
        pdf.text "Effective Location Change Date: #{submission.try(:effective_location_change_date)}" if submission.try(:effective_location_change_date).present?
      end

      if submission.respond_to?(:effective_date_shift_change) && submission.effective_date_shift_change.present?
        pdf.move_down 10
        pdf.text "Additional Information", size: 12, style: :bold
        pdf.text "Effective Date Shift Change: #{submission.effective_date_shift_change}"
        pdf.text "Pay Group Changed: #{submission.try(:pay_group_changed)}" if submission.try(:pay_group_changed).present?
        pdf.text "Work Day Hours Changed: #{submission.try(:work_day_hours_changed)}" if submission.try(:work_day_hours_changed).present?
        pdf.text "Shift Differential - APAF: #{submission.try(:shift_differential_apaf)}" if submission.try(:shift_differential_apaf).present?
        pdf.text "VCHRP Schedule Change Submitted: #{submission.try(:vchrp_schedule_change_submitted)}" if submission.try(:vchrp_schedule_change_submitted).present?
      end

      pdf.move_down 15
      pdf.text "Status: #{submission.status.to_s.tr('_', ' ').titleize}", size: 12, style: :bold

      pdf.move_down 25
      pdf.text "Submitted on: #{submission.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end

  private

  def self.lookup_agency_name(agency_id)
    return agency_id if agency_id.blank?
    agency = Agency.find_by(agency_id: agency_id)
    agency ? agency.long_name : agency_id
  rescue
    agency_id
  end

  def self.lookup_division_name(division_id)
    return division_id if division_id.blank?
    division = Division.find_by(division_id: division_id)
    division ? division.long_name : division_id
  rescue
    division_id
  end

  def self.lookup_department_name(department_id)
    return department_id if department_id.blank?
    department = Department.find_by(department_id: department_id)
    department ? department.long_name : department_id
  rescue
    department_id
  end

  def self.lookup_unit_name(unit_id)
    return unit_id if unit_id.blank?
    unit = Unit.find_by(unit_id: unit_id)
    unit ? "#{unit.unit_id} - #{unit.long_name}" : unit_id
  rescue
    unit_id
  end
end
