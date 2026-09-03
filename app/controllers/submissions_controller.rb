# frozen_string_literal: true

# app/controllers/submissions_controller.rb
class SubmissionsController < ApplicationController
  include Filterable
  include Pagy::Method

  # Legacy forms that are hardcoded (not created via Forms::Template)
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
    employee_id = session.dig(:user, 'employee_id').to_s
    @saved_searches = SavedSearch.for_employee(employee_id).order(:name)

    @status_items = []
    @prefix_map = Forms::Reference.prefix_map

    # Advanced Search (the sidebar modal): org narrowing plus form type, status
    # and category. Shares this page's filter params, so the modal and the
    # filter bar are two ways of writing the same URL.
    @form_search = FormSearch.new(params)

    # System admins can filter across every employee; otherwise the dropdown
    # is gated on having subordinates in the supervisor chain.
    @is_system_admin = current_user_group_names.include?('system_admins')
    @subordinate_ids = Employee.subordinate_ids(employee_id)
    @has_subordinates = @subordinate_ids.any?
    @show_employee_filter = @is_system_admin || @has_subordinates

    # Determine which employee IDs to load submissions for based on filter.
    # nil means "no employee_id restriction" (system admin viewing All).
    # Advanced Search sends `all` so a search spans everything the viewer may
    # see rather than only their own submissions — see the panel's comment.
    @scoped_employee_ids = if @show_employee_filter && params[:filter_employee].present?
                             if params[:filter_employee] == 'all'
                               @is_system_admin ? nil : [employee_id] + @subordinate_ids
                             else
                               [params[:filter_employee]]
                             end
                           else
                             [employee_id]
                           end

    # Visibility grants the viewer holds (direct or via a group) that widen this
    # page — see Forms::VisibilityGrant. Each adds submissions of one form type
    # regardless of submitter, either every one of them or only those filed
    # inside the grant's slice of the organization.
    @viewer_grants = Forms::VisibilityGrant.for_viewer(employee_id, current_user_group_ids).for_submissions.to_a

    # Show the owner column whenever the viewer can see submissions that aren't
    # their own — as a supervisor/admin, or via a visibility grant.
    @show_employee_column = @show_employee_filter || @viewer_grants.any?

    # Resolve the viewer's customized column/filter layout. Done before loading
    # items so build_status_item can populate custom form-field values. The
    # employee column is gated on permission via context.
    @layout = UserSetting.for_employee(employee_id).layout_for(:submissions)
    @columns = TableColumns.resolve(:submissions, @layout, context: { employee_column: @show_employee_column })
    @filter_columns = @columns.select(&:select_filter?)
    @custom_columns = @columns.select(&:custom?)

    # Load legacy hardcoded forms (with SQL-level filters applied)
    load_legacy_forms(employee_id)

    # Load dynamic forms from FormTemplates that have statuses configured
    load_form_template_submissions(employee_id)

    if @show_employee_filter
      # System admins see every employee; supervisors see only their reporting chain.
      @employees = if @is_system_admin
                     Employee.order(:last_name, :first_name)
                   else
                     Employee.where(employee_id: @subordinate_ids).order(:last_name, :first_name)
                   end
      @current_user_id = employee_id
    end

    # Collect unique values for filter dropdowns BEFORE in-memory filtering,
    # keyed by each column's filter param. Category is a standalone filter (not
    # tied to a column) and is always available.
    field_mappings = @filter_columns.index_by { |c| c.filter_param.to_s }
                                    .transform_values(&:value)
    field_mappings['filter_category'] = ->(item) { item[:status_category_label] }
    @filter_options = collect_filter_options(@status_items, field_mappings)

    # Apply in-memory filters — one exact-match config per select-filter column,
    # plus the standalone category filter.
    @status_items = apply_filters(@status_items,
                                  filter_configs: @filter_columns.map { |c| { param: c.filter_param.to_s, extractor: c.value } } +
                                                  [{ param: 'filter_category', extractor: ->(item) { item[:status_category_label] } }],
                                  date_filters: status_date_filters)

    # Reference-number (ID) search, e.g. "PLS-845", "pls-845" or "845".
    if params[:filter_reference].present?
      query = params[:filter_reference]
      @status_items = @status_items.select { |item| Forms::Reference.matches?(item[:reference], query) }
    end

    # Apply sorting. Default falls back gracefully if the user hid Last Updated.
    @default_sort = default_sort_key(@columns, prefer: %w[updated_at submitted_at])
    sort_by = params[:sort_by].presence || @default_sort
    sort_direction = params[:sort_direction] || 'desc'

    @status_items = sort_collection(@status_items, sort_by, sort_direction, status_sort_configs, default_sort: @default_sort)

    # Build status options mapping for JavaScript dynamic filtering
    @status_options_by_type = build_status_options_by_type

    # Paginate the final sorted array
    @pagy, @status_items = pagy(:offset, @status_items, count: @status_items.size)
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

  # Turns a reference number typed into the quick search into the submission it
  # names, and sends the viewer straight to that submission's page — the same
  # place Open lands on the list below, without the trip through the list.
  #
  # Anything that does not resolve to exactly one submission this viewer may see
  # falls back to Submissions filtered by what they typed. That is the honest
  # answer for a bare id, which names one record per form type and so belongs to
  # no single one of them, and for a reference that is real but not theirs to
  # open — the list applies these same visibility rules and simply comes back
  # empty, rather than the lookup confirming the record exists.
  def lookup
    record = referenced_submission(params[:reference])
    return redirect_to(submissions_path(filter_reference: params[:reference])) unless record

    redirect_to submission_path_for(record)
  end

  # Changes a submission's status from its own page. Forms that carry a status
  # dropdown in the inbox keep that control here after they reach an end state
  # and drop out of the queue — the only place they still live is Submissions,
  # so this is where the status has to be changeable, and this is where the user
  # is sent back to afterwards rather than to the inbox.
  def update_status
    record = status_change_record
    return if performed?

    unless helpers.can_change_submission_status?(record)
      redirect_to submission_path_for(record), alert: "You don't have permission to change this submission's status."
      return
    end

    if update_trackable_status(record, params[:status])
      redirect_to submission_path_for(record), notice: "Status changed to #{record.status_label}."
    else
      redirect_to submission_path_for(record), alert: 'That status is not valid for this form.'
    end
  end

  private

  # Resolves :type/:id into a submission this endpoint is willing to act on:
  # one that tracks status and whose form is configured with a status dropdown.
  # Redirects (leaving the action to bail on `performed?`) when it isn't.
  def status_change_record
    klass = application_record_class_named(params[:type])

    unless klass.is_a?(Class) && klass < ApplicationRecord && klass.include?(TrackableStatus)
      redirect_to submissions_path, alert: 'Unknown submission type.'
      return nil
    end

    record = klass.find(params[:id])
    return record if Forms::SubmissionPolicy.status_dropdown?(record)

    redirect_to submissions_path, alert: 'This form does not support changing its status.'
    nil
  rescue ActiveRecord::RecordNotFound
    redirect_to submissions_path, alert: 'Submission not found.'
    nil
  end

  # The one submission a typed reference names, or nil when it names none: an
  # unparseable query, a prefix no form uses, a bare id with no prefix to say
  # which form it belongs to, or a record outside what this viewer may see.
  def referenced_submission(query)
    parsed = Forms::Reference.parse_query(query)
    return nil unless parsed && parsed[:prefix]

    class_name = Forms::Reference.class_name_for_prefix(parsed[:prefix])
    model_class = class_name && application_record_class_named(class_name)
    return nil unless model_class&.table_exists?

    visible_submissions(model_class).find_by(id: parsed[:id])
  end

  # Everything of one form type this viewer may see on the Submissions page:
  # their own submissions and their reporting chain's — everybody's, for a
  # system admin — widened by their visibility grants. index reaches the same
  # place through @scoped_employee_ids, which additionally honours the employee
  # filter; a lookup has no filter bar and wants the widest view the viewer
  # holds, so it asks for that directly.
  #
  # A form that records no submitter is nobody's own, so only a grant opens it.
  def visible_submissions(model_class)
    employee_id = session.dig(:user, 'employee_id').to_s
    own = if current_user_group_names.include?('system_admins')
            model_class.all
          elsif model_class.column_names.include?('employee_id')
            model_class.where(employee_id: [employee_id] + Employee.subordinate_ids(employee_id))
          else
            model_class.none
          end

    grants = Forms::VisibilityGrant.for_viewer(employee_id, current_user_group_ids).for_submissions.to_a
    Forms::VisibilityGrant.widen(own, grants, model_class)
  end

  # The submission's own page, so a status change lands back where it started.
  # Falls back to the Submissions list for anything without a show route.
  def submission_path_for(record)
    polymorphic_path(record)
  rescue StandardError
    submissions_path
  end

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
    Forms::Template.joins(:statuses).distinct.each do |template|
      model_class = application_record_class_named(template.class_name)
      next unless model_class

      statuses = statuses_from_model(model_class)
      options[template.name] = statuses
    end

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
    template = Forms::Template.find_by(name: form_type)
    if template
      model_class = application_record_class_named(template.class_name)
      return [] unless model_class

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

    Forms::Template.joins(:statuses).distinct.each do |template|
      model_class = application_record_class_named(template.class_name)
      next unless model_class

      all_statuses.merge(statuses_from_model(model_class))
    end

    all_statuses.to_a.sort
  end

  def load_legacy_forms(_employee_id)
    LEGACY_FORMS.each do |form_config|
      # Skip tables that don't match the type filter (avoids querying unnecessary tables)
      next unless @form_search.include_form_type?(form_config[:type])

      model_class = form_config[:model].constantize
      next unless model_class.table_exists?
      next unless model_class.respond_to?(:status_category) || model_class.new.respond_to?(:status_category)

      # Build includes based on model associations
      includes_list = []
      includes_list << :parking_lot_vehicles if model_class.reflect_on_association(:parking_lot_vehicles)

      # Scope to the determined employee IDs (own, specific subordinate, or all);
      # a visibility grant on this form type widens it.
      scope = submission_scope_for(model_class)

      # Apply SQL-level date and Advanced Search org filters
      scope = apply_scope_date_filters(scope, submission_scope_date_filters)
      scope = @form_search.apply_org(model_class, scope)

      # Apply eager loading
      scope = scope.includes(includes_list) if includes_list.any?

      scope.each do |submission|
        path = send(form_config[:path_helper], submission)
        @status_items << build_status_item(submission, form_config[:type], path)
      end
    rescue NameError
      # Model doesn't exist, skip
      next
    end
  end

  # Model names already loaded by LEGACY_FORMS to avoid double-counting
  LEGACY_MODEL_NAMES = LEGACY_FORMS.to_set { |f| f[:model] }.freeze

  def load_form_template_submissions(_employee_id)
    # Find all form templates that have statuses configured
    Forms::Template.joins(:statuses).distinct.each do |template|
      # Skip templates that don't match the type filter
      next unless @form_search.include_form_type?(template.name)

      # Skip models already handled by LEGACY_FORMS
      next if LEGACY_MODEL_NAMES.include?(template.class_name)

      model_class = template.class_name.constantize
      next unless model_class.table_exists?

      # Check if model includes TrackableStatus (has status_category method)
      next unless model_class.new.respond_to?(:status_category)

      # Scope to the determined employee IDs (own, specific subordinate, or all);
      # a visibility grant on this form type widens it.
      scope = submission_scope_for(model_class)

      # Apply SQL-level date and Advanced Search org filters
      scope = apply_scope_date_filters(scope, submission_scope_date_filters)
      scope = @form_search.apply_org(model_class, scope)

      scope.each do |submission|
        # Generate path dynamically based on the model's route
        path = generate_submission_path(template, submission)
        @status_items << build_status_item(submission, template.name, path)
      end
    rescue NameError
      # Model doesn't exist yet (form template created but not generated), skip
      next
    end
  end

  # Records of model_class to load for the Submissions list: the viewer's own /
  # subordinates' submissions (nil ids = no restriction, i.e. system admin
  # viewing All), widened by whatever their visibility grants open up — every
  # submission of the granted form type, or only the ones filed inside the
  # grant's org window.
  def submission_scope_for(model_class)
    own = @scoped_employee_ids ? model_class.where(employee_id: @scoped_employee_ids) : model_class.all

    Forms::VisibilityGrant.widen(own, @viewer_grants, model_class)
  end

  # SQL-level date filter config (applied per-table before combining)
  def submission_scope_date_filters
    [
      { param: :filter_date_from, column: :created_at, comparison: :from },
      { param: :filter_date_to, column: :created_at, comparison: :to }
    ]
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

    item = {
      id: submission.id,
      reference: Forms::Reference.reference_for(submission, @prefix_map),
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
      unit: submission.try(:unit)
    }

    # Populate any custom form-field columns the viewer added. A field only
    # exists on its own form's rows; others stay blank.
    Array(@custom_columns).each do |col|
      (item[:custom] ||= {})[col.id] =
        submission.respond_to?(col.field) ? submission.public_send(col.field) : nil
    end

    item
  end

  def status_date_filters
    # Date filters are now applied at SQL level in load methods,
    # but we keep the in-memory fallback for any items that slipped through
    []
  end

  # Sort configs derived from the visible columns. Reference keeps its custom
  # zero-padded key so ids sort numerically within a prefix; every other
  # sortable column sorts on its raw extractor value.
  def status_sort_configs
    configs = {
      'reference' => lambda { |item|
        prefix, id = item[:reference].to_s.split('-')
        format('%s-%012d', prefix.to_s, id.to_i)
      }
    }
    Array(@columns).each do |col|
      next unless col.sortable?
      next if col.sort_key == 'reference'

      extractor = col.value
      configs[col.sort_key] = ->(item) { extractor.call(item).to_s }
    end
    configs
  end
end
