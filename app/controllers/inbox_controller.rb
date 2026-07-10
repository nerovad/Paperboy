# app/controllers/inbox_controller.rb
class InboxController < ApplicationController
  include Filterable
  include Pagy::Method

  def queue
    employee = session[:user]
    return @submissions = [] unless employee.present? && employee['employee_id'].present?

    employee_id = employee['employee_id'].to_s
    @submissions = []

    # System admins can filter across every employee's inbox; otherwise the
    # dropdown is gated on having subordinates in the supervisor chain.
    @is_system_admin = current_user_group_names.include?('system_admins')
    @subordinate_ids = Employee.subordinate_ids(employee_id)
    @has_subordinates = @subordinate_ids.any?
    @show_employee_filter = @is_system_admin || @has_subordinates

    # Form-wide visibility grants: class names of forms this user may see every
    # submission of (via a granted group). Surfaced only when the user explicitly
    # filters the inbox to that form type — see InboxQuery#granted_submissions.
    @viewer_form_types = FormVisibilityGrant.form_types_for(employee_id, current_user_group_ids)

    # nil means "no assignee restriction" (system admin viewing All).
    @scoped_employee_ids = if @show_employee_filter && params[:filter_employee].present?
                             if params[:filter_employee] == 'all'
                               @is_system_admin ? nil : [employee_id] + @subordinate_ids
                             else
                               [params[:filter_employee]]
                             end
                           else
                             [employee_id]
                           end

    # Assemble the inbox contents (probation, CIR, routed dynamic forms, and
    # granted form types — deduped, with terminal items dropped). Shared with the
    # profile/tab badge via InboxQuery so the count can't drift from the page.
    # Parking permits flow entirely through the dynamic-form path: their print/
    # pickup steps are non-terminal and stay actionable, while a picked-up
    # (approved) permit drops out with the rest of the terminal items.
    inbox = InboxQuery.new(
      scoped_employee_ids: @scoped_employee_ids,
      viewer_form_types: @viewer_form_types,
      filter_form_type: params[:filter_form_type],
      date_from: params[:filter_date_from],
      date_to: params[:filter_date_to]
    )
    @submissions = inbox.submissions
    @copy_submission_ids = inbox.copy_submission_ids

    # Resolve the viewer's customized column/filter layout for this page. Each
    # visible column can render as a table column and, when it carries a select
    # filter, as a filter-bar dropdown.
    @layout = UserSetting.for_employee(employee_id).layout_for(:inbox)
    @columns = TableColumns.resolve(:inbox, @layout)
    @filter_columns = @columns.select(&:select_filter?)

    # Collect unique values for filter dropdowns BEFORE in-memory filtering,
    # keyed by each column's filter param.
    field_mappings = @filter_columns.index_by { |c| c.filter_param.to_s }
                                    .transform_values(&:value)
    @filter_options = collect_filter_options(@submissions, field_mappings)

    # Granted form types must be selectable even when no rows are loaded yet —
    # their submissions only load once this filter is applied.
    if @filter_options.key?('filter_form_type')
      granted_labels = @viewer_form_types.filter_map do |class_name|
        class_name.safe_constantize&.name&.demodulize&.titleize
      end
      if granted_labels.any?
        @filter_options['filter_form_type'] =
          (@filter_options['filter_form_type'] + granted_labels).uniq.sort_by { |v| v.to_s.downcase }
      end
    end

    # Apply in-memory filters — one exact-match config per select-filter column.
    @submissions = apply_filters(@submissions,
                                 filter_configs: @filter_columns.map { |c| { param: c.filter_param.to_s, extractor: c.value } },
                                 date_filters: inbox_date_filters)

    # Reference-number search (e.g. "LOA-1042", "loa-1042" or "1042"). Filters
    # the already-scoped list, so a reference the viewer can't see won't match.
    @prefix_map = FormReference.prefix_map
    if params[:filter_reference].present?
      query = params[:filter_reference]
      @submissions = @submissions.select do |s|
        FormReference.matches?(FormReference.reference_for(s, @prefix_map), query)
      end
    end

    # Apply sorting. The default falls back gracefully if the user hid the
    # Created column so it can't be a phantom sort key.
    @default_sort = default_sort_key(@columns, prefer: %w[created_at updated_at])
    sort_by = params[:sort_by].presence || @default_sort
    sort_direction = params[:sort_direction] || 'desc'

    @submissions = sort_collection(@submissions, sort_by, sort_direction, inbox_sort_configs, default_sort: @default_sort)

    # Paginate the final sorted array
    @pagy, @submissions = pagy(:offset, @submissions, count: @submissions.size)

    # Reassignment modal needs every employee regardless of filter scope.
    @employees = Employee.order(:last_name, :first_name)

    # Filter dropdown: system admins see every employee; supervisors see only their reporting chain.
    return unless @show_employee_filter

    @filter_employees = @is_system_admin ? @employees : Employee.where(employee_id: @subordinate_ids).order(:last_name, :first_name)
    @current_user_id = employee_id
  end

  # Renders the workflow status timeline for a single submission as an HTML
  # fragment, loaded on demand into the inbox "Status History" modal. Restricted
  # to models that actually track status (include TrackableStatus) so the type
  # param can't be used to render arbitrary records.
  def status_history
    klass = application_record_class_named(params[:type])

    head :not_found and return unless klass.is_a?(Class) && klass < ApplicationRecord && klass.include?(TrackableStatus)

    record = klass.find(params[:id])
    changes = record.status_timeline.to_a

    render partial: 'submissions/status_timeline',
           locals: { status_changes: changes, item_id: "inbox-#{klass.name}-#{record.id}" },
           layout: false
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def inbox_date_filters
    # Date filters are now applied at SQL level
    []
  end

  # Sort configs derived from the visible columns. Reference keeps its custom
  # zero-padded key so ids sort numerically within a prefix; every other
  # sortable column sorts on its raw extractor value.
  def inbox_sort_configs
    configs = {
      'reference' => lambda { |s|
        ref = FormReference.reference_for(s, @prefix_map) || ''
        prefix, id = ref.split('-')
        format('%s-%012d', prefix.to_s, id.to_i)
      }
    }
    Array(@columns).each do |col|
      next unless col.sortable?
      next if col.sort_key == 'reference'

      extractor = col.value
      configs[col.sort_key] = ->(s) { extractor.call(s).to_s }
    end
    configs
  end
end
