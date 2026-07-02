# app/controllers/inbox_controller.rb
class InboxController < ApplicationController
  include Filterable
  include Pagy::Method

  def queue
    employee = session[:user]
    return @submissions = [] unless employee.present? && employee["employee_id"].present?

    employee_id = employee["employee_id"].to_s
    @submissions = []

    # System admins can filter across every employee's inbox; otherwise the
    # dropdown is gated on having subordinates in the supervisor chain.
    @is_system_admin = current_user_group_names.include?("system_admins")
    @subordinate_ids = Employee.subordinate_ids(employee_id)
    @has_subordinates = @subordinate_ids.any?
    @show_employee_filter = @is_system_admin || @has_subordinates

    # Form-wide visibility grants: class names of forms this user may see every
    # submission of (via a granted group). Surfaced only when the user explicitly
    # filters the inbox to that form type — see InboxQuery#granted_submissions.
    @viewer_form_types = FormVisibilityGrant.form_types_for(employee_id, current_user_group_ids)

    # nil means "no assignee restriction" (system admin viewing All).
    @scoped_employee_ids = if @show_employee_filter && params[:filter_employee].present?
                             if params[:filter_employee] == "all"
                               @is_system_admin ? nil : [ employee_id ] + @subordinate_ids
                             else
                               [ params[:filter_employee] ]
                             end
    else
                             [ employee_id ]
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

    # Collect unique values for filter dropdowns BEFORE in-memory filtering
    @filter_options = collect_filter_options(@submissions, inbox_field_mappings)

    # Granted form types must be selectable even when no rows are loaded yet —
    # their submissions only load once this filter is applied.
    granted_labels = @viewer_form_types.filter_map do |class_name|
      class_name.safe_constantize&.name&.demodulize&.titleize
    end
    if granted_labels.any?
      @filter_options[:form_types] = (@filter_options[:form_types] + granted_labels)
                                     .uniq.sort_by { |v| v.to_s.downcase }
    end

    # Apply in-memory filters
    @submissions = apply_filters(@submissions,
      filter_configs: inbox_filter_configs,
      date_filters: inbox_date_filters
    )

    # Reference-number search (e.g. "LOA-1042", "loa-1042" or "1042"). Filters
    # the already-scoped list, so a reference the viewer can't see won't match.
    @prefix_map = FormReference.prefix_map
    if params[:filter_reference].present?
      query = params[:filter_reference]
      @submissions = @submissions.select do |s|
        FormReference.matches?(FormReference.reference_for(s, @prefix_map), query)
      end
    end

    # Apply sorting
    sort_by = params[:sort_by] || "created_at"
    sort_direction = params[:sort_direction] || "desc"

    @submissions = sort_collection(@submissions, sort_by, sort_direction, inbox_sort_configs)

    # Paginate the final sorted array
    @pagy, @submissions = pagy(:offset, @submissions, count: @submissions.size)

    # Reassignment modal needs every employee regardless of filter scope.
    @employees = Employee.order(:last_name, :first_name)

    # Filter dropdown: system admins see every employee; supervisors see only their reporting chain.
    if @show_employee_filter
      @filter_employees = @is_system_admin ? @employees : Employee.where(employee_id: @subordinate_ids).order(:last_name, :first_name)
      @current_user_id = employee_id
    end
  end

  # Renders the workflow status timeline for a single submission as an HTML
  # fragment, loaded on demand into the inbox "Status History" modal. Restricted
  # to models that actually track status (include TrackableStatus) so the type
  # param can't be used to render arbitrary records.
  def status_history
    klass = application_record_class_named(params[:type])

    unless klass.is_a?(Class) && klass < ApplicationRecord && klass.include?(TrackableStatus)
      head :not_found and return
    end

    record = klass.find(params[:id])
    changes = record.status_timeline.to_a

    render partial: "submissions/status_timeline",
           locals: { status_changes: changes, item_id: "inbox-#{klass.name}-#{record.id}" },
           layout: false
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def inbox_field_mappings
    {
      form_types: ->(s) { s.class.name.demodulize.titleize },
      names: ->(s) { s.name },
      units: ->(s) { s.try(:unit) },
      emails: ->(s) { s.email },
      statuses: ->(s) { s.status_label }
    }
  end

  def inbox_filter_configs
    [
      { param: :filter_form_type, extractor: ->(s) { s.class.name.demodulize.titleize } },
      { param: :filter_name, extractor: ->(s) { s.name } },
      { param: :filter_unit, extractor: ->(s) { s.try(:unit) } },
      { param: :filter_email, extractor: ->(s) { s.email } },
      { param: :filter_status, extractor: ->(s) { s.status_label } }
    ]
  end

  def inbox_date_filters
    # Date filters are now applied at SQL level
    []
  end

  def inbox_sort_configs
    {
      "reference" => ->(s) {
        ref = FormReference.reference_for(s, @prefix_map) || ""
        prefix, id = ref.split("-")
        # Zero-pad the id so it sorts numerically within a prefix (the sort
        # helper compares the stringified value).
        format("%s-%012d", prefix.to_s, id.to_i)
      },
      "form_type" => ->(s) { s.class.name.demodulize.titleize },
      "name" => ->(s) { s.name.to_s },
      "unit" => ->(s) { (s.try(:unit) || "").to_s },
      "email" => ->(s) { s.email.to_s },
      "status" => ->(s) { s.status_label.to_s },
      "created_at" => ->(s) { s.created_at.to_s }
    }
  end
end
