# app/controllers/status_controller.rb
class StatusController < ApplicationController
  include Filterable

  # Legacy forms that are hardcoded (not created via FormTemplate)
  LEGACY_FORMS = [
    { model: 'ParkingLotSubmission', type: 'Parking Lot', path_helper: :parking_lot_submission_path },
    { model: 'ProbationTransferRequest', type: 'Probation Transfer', path_helper: :probation_transfer_request_path },
    { model: 'CriticalInformationReporting', type: 'Critical Information Report', path_helper: :edit_critical_information_reporting_path }
  ].freeze

  def index
    employee_id = session.dig(:user, "employee_id").to_s
    @is_manager = current_user&.in_group?("Status Managers")

    @status_items = []

    # Load legacy hardcoded forms
    load_legacy_forms(employee_id)

    # Load dynamic forms from FormTemplates that have statuses configured
    load_form_template_submissions(employee_id)

    if @is_manager
      # Load employees from GSABSS for filter dropdowns
      @employees = Employee.order(:Last_Name, :First_Name)

      # Current user info for "Myself" filter option
      @current_user_name = "#{session.dig(:user, 'first_name')} #{session.dig(:user, 'last_name')}"
      @current_user_id = employee_id
    end

    # Collect unique values for filter dropdowns before filtering
    @filter_options = collect_filter_options(@status_items, status_field_mappings)

    # Apply filters
    @status_items = apply_filters(@status_items,
      filter_configs: status_filter_configs,
      date_filters: status_date_filters
    )

    # Apply sorting
    sort_by = params[:sort_by] || 'updated_at'
    sort_direction = params[:sort_direction] || 'desc'

    @status_items = sort_collection(@status_items, sort_by, sort_direction, status_sort_configs, default_sort: 'updated_at')
  end

  private

  def load_legacy_forms(employee_id)
    LEGACY_FORMS.each do |form_config|
      model_class = form_config[:model].constantize
      next unless model_class.table_exists?
      next unless model_class.respond_to?(:status_category) || model_class.new.respond_to?(:status_category)

      submissions = if @is_manager
                      model_class.includes(:status_changes)
                    else
                      model_class.for_employee(employee_id).includes(:status_changes)
                    end

      submissions.each do |submission|
        path = send(form_config[:path_helper], submission)
        @status_items << build_status_item(submission, form_config[:type], path)
      end
    rescue NameError
      # Model doesn't exist, skip
      next
    end
  end

  def load_form_template_submissions(employee_id)
    # Find all form templates that have statuses configured
    FormTemplate.joins(:statuses).distinct.each do |template|
      model_class = template.class_name.constantize
      next unless model_class.table_exists?

      # Check if model includes TrackableStatus (has status_category method)
      next unless model_class.new.respond_to?(:status_category)

      submissions = if @is_manager
                      model_class.includes(:status_changes)
                    else
                      if model_class.respond_to?(:for_employee)
                        model_class.for_employee(employee_id).includes(:status_changes)
                      else
                        model_class.where(employee_id: employee_id).includes(:status_changes)
                      end
                    end

      submissions.each do |submission|
        # Generate path dynamically based on the model's route
        path = generate_submission_path(template, submission)
        @status_items << build_status_item(submission, template.name, path)
      end
    rescue NameError
      # Model doesn't exist yet (form template created but not generated), skip
      next
    end
  end

  def generate_submission_path(template, submission)
    # Try to use the standard RESTful path helper
    route_name = template.class_name.underscore
    path_helper = "#{route_name}_path"

    if respond_to?(path_helper, true)
      send(path_helper, submission)
    else
      # Fallback to edit path
      edit_path_helper = "edit_#{route_name}_path"
      if respond_to?(edit_path_helper, true)
        send(edit_path_helper, submission)
      else
        # Last resort: construct path manually
        "/#{route_name.pluralize}/#{submission.id}"
      end
    end
  end

  def build_status_item(submission, type, path)
    {
      id: submission.id,
      type: type,
      title: "#{type} ##{submission.id}",
      status: submission.status_label,
      status_category: submission.status_category,
      status_category_label: submission.status_category_label,
      submitted_at: submission.created_at,
      updated_at: submission.updated_at,
      path: path,
      employee_id: submission.employee_id,
      employee_name: submission.name,
      status_changes: submission.status_changes.chronological.to_a
    }
  end

  def status_field_mappings
    {
      types: ->(item) { item[:type] },
      statuses: ->(item) { item[:status].to_s.tr('_', ' ').titleize },
      categories: ->(item) { item[:status_category_label] }
    }
  end

  def status_filter_configs
    configs = [
      { param: :filter_type, extractor: ->(item) { item[:type] } },
      { param: :filter_status, extractor: ->(item) { item[:status].to_s.tr('_', ' ').titleize } },
      { param: :filter_category, extractor: ->(item) { item[:status_category_label] } }
    ]

    if @is_manager
      configs << { param: :filter_employee_name, extractor: ->(item) { item[:employee_name] } }
      configs << { param: :filter_employee_id, extractor: ->(item) { item[:employee_id] } }
    end

    configs
  end

  def status_date_filters
    [
      { param: :filter_date_from, extractor: ->(item) { item[:submitted_at] }, comparison: :from },
      { param: :filter_date_to, extractor: ->(item) { item[:submitted_at] }, comparison: :to }
    ]
  end

  def status_sort_configs
    configs = {
      'type' => ->(item) { item[:type].to_s },
      'title' => ->(item) { item[:title].to_s },
      'status' => ->(item) { item[:status].to_s },
      'submitted_at' => ->(item) { item[:submitted_at].to_s },
      'updated_at' => ->(item) { item[:updated_at].to_s }
    }

    if @is_manager
      configs['employee_name'] = ->(item) { item[:employee_name].to_s }
      configs['employee_id'] = ->(item) { item[:employee_id].to_s }
    end

    configs
  end
end
