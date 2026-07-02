require "prawn"

class SafetyReportPdfGenerator
  def self.generate(submission)
    logo_path = Rails.root.join("app", "assets", "images", "Ventura_Logo.png")

    Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
      pdf.image(logo_path.to_s, width: 80) if File.exist?(logo_path)

      pdf.move_down 10
      pdf.text "Safety Reporting", size: 22, style: :bold, align: :center
      PdfReference.render(pdf, submission)
      pdf.move_down 20

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

      render_form_builder_fields(pdf, submission)

      pdf.move_down 15
      pdf.text "Status: #{submission.status.to_s.tr('_', ' ').titleize}", size: 12, style: :bold

      pdf.move_down 25
      PdfWorkflowHistory.render(pdf, submission)

      pdf.text "Submitted on: #{submission.created_at.strftime('%B %d, %Y at %I:%M %p')}", size: 10, align: :right
    end.render
  end

  def self.render_form_builder_fields(pdf, submission)
    template = submission.form_template
    return unless template

    fields = template.form_fields.ordered.where("page_number >= 3").to_a
    return if fields.empty?

    fields.group_by(&:page_number).each do |page_num, page_fields|
      visible = page_fields.select { |f| field_visible?(f, submission) }
      next if visible.empty?

      pdf.move_down 15
      pdf.text(template.page_header(page_num).presence || "Page #{page_num}", size: 14, style: :bold)
      pdf.move_down 5

      visible.each do |field|
        if field.information?
          pdf.text field.information_text.to_s, style: :italic if field.information_text.present?
          next
        end

        next if field.field_type == "media_attachment"

        value = format_value(field, submission)
        pdf.text "#{field.label}: #{value}"
      end
    end
  end

  def self.field_visible?(field, submission)
    return true unless field.conditional?

    parent = field.conditional_field
    return true unless parent

    parent_value = submission.send(parent.field_name) if submission.respond_to?(parent.field_name)
    field.visible_for_value?(parent_value)
  end

  def self.format_value(field, submission)
    return "—" unless submission.respond_to?(field.field_name)

    raw = submission.send(field.field_name)
    return "—" if raw.nil? || (raw.respond_to?(:blank?) && raw.blank?)

    case field.field_type
    when "date"
      raw.respond_to?(:strftime) ? raw.strftime("%B %d, %Y") : raw.to_s
    when "date_time"
      raw.respond_to?(:strftime) ? raw.strftime("%B %d, %Y at %I:%M %p") : raw.to_s
    when "time"
      raw.respond_to?(:strftime) ? raw.strftime("%I:%M %p") : raw.to_s
    when "currency"
      ActionController::Base.helpers.number_to_currency(raw)
    else
      raw.to_s
    end
  end

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
