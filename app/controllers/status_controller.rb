# app/controllers/status_controller.rb
class StatusController < ApplicationController
  include Filterable

  # Legacy forms that are hardcoded (not created via FormTemplate)
  LEGACY_FORMS = [
    { model: 'ParkingLotSubmission', type: 'Parking Lot', path_helper: :parking_lot_submission_path },
    { model: 'ProbationTransferRequest', type: 'Probation Transfer', path_helper: :probation_transfer_request_path },
    { model: 'CriticalInformationReporting', type: 'Critical Information Report', path_helper: :critical_information_reporting_path }
  ].freeze

  # Map form type display names to model classes
  FORM_TYPE_TO_MODEL = {
    'Parking Lot' => 'ParkingLotSubmission',
    'Probation Transfer' => 'ProbationTransferRequest',
    'Critical Information Report' => 'CriticalInformationReporting'
  }.freeze

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

    # Build status options mapping for JavaScript dynamic filtering
    @status_options_by_type = build_status_options_by_type

    # Build title options mapping for JavaScript dynamic filtering
    @title_options_by_type = build_title_options_by_type(@status_items)
  end

  def status_options
    form_type = params[:type]

    if form_type.blank?
      # Return all statuses from all forms
      all_statuses = collect_all_statuses
      render json: { statuses: all_statuses }
    else
      statuses = statuses_for_form_type(form_type)
      render json: { statuses: statuses }
    end
  end

  private

  def build_status_options_by_type
    options = {}

    # Legacy forms
    LEGACY_FORMS.each do |form_config|
      model_class = form_config[:model].constantize
      statuses = statuses_from_model(model_class)
      options[form_config[:type]] = statuses
    rescue NameError
      next
    end

    # Dynamic forms from FormTemplates
    FormTemplate.joins(:statuses).distinct.each do |template|
      model_class = template.class_name.constantize
      statuses = statuses_from_model(model_class)
      options[template.name] = statuses
    rescue NameError
      next
    end

    options
  end

  def build_title_options_by_type(status_items)
    options = {}

    status_items.each do |item|
      type = item[:type]
      title = item[:title]
      options[type] ||= []
      options[type] << title unless options[type].include?(title)
    end

    # Sort titles within each type
    options.each { |_type, titles| titles.sort! }

    options
  end

  def statuses_for_form_type(form_type)
    # Check legacy forms first
    model_name = FORM_TYPE_TO_MODEL[form_type]

    if model_name
      model_class = model_name.constantize
      return statuses_from_model(model_class)
    end

    # Check dynamic forms
    template = FormTemplate.find_by(name: form_type)
    if template
      model_class = template.class_name.constantize
      return statuses_from_model(model_class)
    end

    []
  rescue NameError
    []
  end

  def statuses_from_model(model_class)
    if model_class.respond_to?(:statuses)
      # Model uses enum :status
      model_class.statuses.keys.map { |s| s.to_s.tr('_', ' ').titleize }
    elsif model_class.const_defined?(:STATUS_MAP)
      # Model uses STATUS_MAP (like ProbationTransferRequest)
      model_class::STATUS_MAP.values.map { |s| s.to_s.tr('_', ' ').titleize }
    else
      []
    end
  end

  def collect_all_statuses
    all_statuses = Set.new

    LEGACY_FORMS.each do |form_config|
      model_class = form_config[:model].constantize
      all_statuses.merge(statuses_from_model(model_class))
    rescue NameError
      next
    end

    FormTemplate.joins(:statuses).distinct.each do |template|
      model_class = template.class_name.constantize
      all_statuses.merge(statuses_from_model(model_class))
    rescue NameError
      next
    end

    all_statuses.to_a.sort
  end

  def load_legacy_forms(employee_id)
    LEGACY_FORMS.each do |form_config|
      model_class = form_config[:model].constantize
      next unless model_class.table_exists?
      next unless model_class.respond_to?(:status_category) || model_class.new.respond_to?(:status_category)

      # Build includes based on model associations
      includes_list = []
      includes_list << :parking_lot_vehicles if model_class.reflect_on_association(:parking_lot_vehicles)

      submissions = if @is_manager
                      includes_list.any? ? model_class.includes(includes_list) : model_class.all
                    else
                      scope = model_class.for_employee(employee_id)
                      includes_list.any? ? scope.includes(includes_list) : scope
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
                      model_class.all
                    else
                      if model_class.respond_to?(:for_employee)
                        model_class.for_employee(employee_id)
                      else
                        model_class.where(employee_id: employee_id)
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
    title = case type
            when 'Critical Information Report'
              if submission.respond_to?(:incident_type) && submission.incident_type.present?
                submission.incident_type
              else
                "#{type} ##{submission.id}"
              end
            when 'Parking Lot'
              if submission.respond_to?(:parking_lot_vehicles) && submission.parking_lot_vehicles.first&.parking_lot.present?
                submission.parking_lot_vehicles.first.display_parking_lot
              else
                "#{type} ##{submission.id}"
              end
            else
              "#{type} ##{submission.id}"
            end

    {
      id: submission.id,
      type: type,
      title: title,
      status: submission.status_label,
      status_category: submission.status_category,
      status_category_label: submission.status_category_label,
      submitted_at: submission.created_at,
      updated_at: submission.updated_at,
      path: path,
      employee_id: submission.employee_id,
      employee_name: submission.name,
    }
  end

  def status_field_mappings
    {
      types: ->(item) { item[:type] },
      titles: ->(item) { item[:title] },
      statuses: ->(item) { item[:status].to_s.tr('_', ' ').titleize },
      categories: ->(item) { item[:status_category_label] }
    }
  end

  def status_filter_configs
    configs = [
      { param: :filter_type, extractor: ->(item) { item[:type] } },
      { param: :filter_title, extractor: ->(item) { item[:title] } },
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
