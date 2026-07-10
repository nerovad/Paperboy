# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  before_action :require_reports_access

  def index
    @forms = available_forms

    # Load user's scheduled reports (if model exists)
    employee_id = session.dig(:user, 'employee_id')
    @scheduled_reports = if defined?(ScheduledReport) && employee_id
                           ScheduledReport.for_employee(employee_id).order(created_at: :desc)
                         else
                           []
                         end
  end

  def generate
    form_type = params[:form_type]
    format_param = params[:format]
    status = params[:status] # Optional status filter
    employee_id = session.dig(:user, 'employee_id')

    if form_type.blank? || format_param.blank?
      redirect_to reports_path, alert: 'Please fill in all required fields'
      return
    end

    # Verify user has form-level permission for this form type
    unless current_user_group_names.include?('system_admins') || permitted_form_type?(form_type)
      redirect_to reports_path, alert: 'You do not have permission to generate reports for this form.'
      return
    end

    # Check if this is a scheduled report
    if params[:schedule] == '1'
      # Create scheduled report
      create_scheduled_report(employee_id, form_type, format_param, status)
    else
      # Generate one-time report
      generate_one_time_report(employee_id, form_type, format_param, status)
    end
  end

  def status_options
    form_type = params[:form_type]

    begin
      # Get the model class
      template = FormTemplate.all.find { |t| t.class_name.tableize == form_type }

      if template.nil?
        render json: { status_options: [] }
        return
      end

      model_class = application_record_class_named(template.class_name)
      unless model_class
        render json: { status_options: [] }
        return
      end

      # Prefer the model's human-readable STATUS_LABELS (via TrackableStatus)
      # over the raw enum/STATUS_MAP key — "Sent to HCA_HR" instead of
      # "Step 1 Pending". Falls back to titleized key when no label is defined.
      label_for = lambda { |int_value, fallback_key|
        (model_class.respond_to?(:status_label_for) && model_class.status_label_for(int_value)) ||
          fallback_key.to_s.titleize
      }

      # Check if model has STATUS_MAP constant
      if model_class.const_defined?(:STATUS_MAP)
        status_map = model_class::STATUS_MAP

        # Convert to array of {value, label} for the dropdown
        options = status_map.map do |int_value, label|
          {
            value: int_value.to_s,
            label: label_for.call(int_value, label)
          }
        end.sort_by { |opt| opt[:value].to_i }

        render json: { status_options: options }
      # Check if model uses Rails enum for status
      elsif model_class.defined_enums.key?('status')
        status_enum = model_class.defined_enums['status']

        # Convert enum hash to array of {value, label} for the dropdown
        # Enum returns {"submitted" => 0, "approved" => 1, ...}
        options = status_enum.map do |label, int_value|
          {
            value: int_value.to_s,
            label: label_for.call(int_value, label)
          }
        end.sort_by { |opt| opt[:value].to_i }

        render json: { status_options: options }
      else
        # No STATUS_MAP or status enum defined
        render json: { status_options: [] }
      end
    rescue StandardError => e
      Rails.logger.error "Error fetching status options: #{e.message}"
      render json: { status_options: [] }
    end
  end

  private

  def generate_one_time_report(employee_id, form_type, format, status)
    start_date = begin
      Date.parse(params[:start_date])
    rescue StandardError
      nil
    end
    end_date = begin
      Date.parse(params[:end_date])
    rescue StandardError
      nil
    end

    if start_date.nil? || end_date.nil?
      redirect_to reports_path, alert: 'Invalid date format'
      return
    end

    if start_date > end_date
      redirect_to reports_path, alert: 'Start date must be before end date'
      return
    end

    # Queue the report generation job (status can be nil/blank)
    ReportGenerationJob.perform_later(
      employee_id,
      form_type,
      start_date.to_s,
      end_date.to_s,
      format,
      status.presence
    )

    redirect_to reports_path, notice: "Your report is being generated. You will receive an email when it's ready."
  end

  def create_scheduled_report(employee_id, form_type, format, status)
    unless defined?(ScheduledReport)
      redirect_to reports_path, alert: 'Scheduled reports feature is not yet set up. Please complete the installation steps.'
      return
    end

    scheduled_report = ScheduledReport.new(
      employee_id: employee_id,
      form_type: form_type,
      format: format,
      status_filter: status.presence,
      date_range_type: params[:date_range_type],
      frequency: params[:frequency],
      time_of_day: params[:time_of_day],
      day_of_week: params[:day_of_week],
      day_of_month: params[:day_of_month]
    )

    scheduled_report.next_run_at = scheduled_report.calculate_next_run

    if scheduled_report.save
      next_run = scheduled_report.next_run_at.strftime('%B %d at %I:%M %p')
      redirect_to reports_path, notice: "Scheduled report created successfully. Next run: #{next_run}"
    else
      redirect_to reports_path, alert: "Error creating scheduled report: #{scheduled_report.errors.full_messages.join(', ')}"
    end
  end

  def available_forms
    templates = FormTemplate.all.order(:name)

    # Non-admins only see forms they have ACL permission for
    unless current_user_group_names.include?('system_admins')
      perm_keys = current_user_form_permission_keys
      templates = templates.select { |t| perm_keys.include?(t.id.to_s) }
    end

    templates.map do |template|
      {
        name: template.name,
        value: template.class_name.tableize # Converts "ParkingLotSubmission" → "parking_lot_submissions"
      }
    end
  end

  def permitted_form_type?(form_type)
    template = FormTemplate.all.find { |t| t.class_name.tableize == form_type }
    return false unless template

    current_user_form_permission_keys.include?(template.id.to_s)
  end

  def require_reports_access
    return if current_user_group_names.include?('system_admins') || current_user_dropdown_permissions.include?('reports')

    redirect_to root_path, alert: 'Access denied.'
  end
end
