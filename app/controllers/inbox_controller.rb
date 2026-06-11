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

    # nil means "no assignee restriction" (system admin viewing All).
    @scoped_employee_ids = if @show_employee_filter && params[:filter_employee].present?
                             if params[:filter_employee] == "all"
                               @is_system_admin ? nil : [employee_id] + @subordinate_ids
                             else
                               [params[:filter_employee]]
                             end
                           else
                             [employee_id]
                           end

    # Parking Lot Submissions where assignee is either:
    # 1. Supervisor (Dept Head) - all statuses stay in inbox
    # 2. Delegated Approver - all statuses stay in inbox
    # 3. Unclaimed (supervisor_id IS NULL) and the scoped employee is one of
    #    the authorized approvers for the submission's unit. Restricted to
    #    pending submissions; once an approver acts, supervisor_id is set
    #    via the claim and path 1 takes over.
    @submissions += apply_scope_date_filters(
      scope_by_assignee(ParkingLotSubmission, :supervisor_id),
      inbox_scope_date_filters
    ).to_a
    @submissions += apply_scope_date_filters(
      scope_by_assignee(ParkingLotSubmission, :delegated_approver_id),
      inbox_scope_date_filters
    ).to_a
    @submissions += apply_scope_date_filters(
      scope_unclaimed_by_authorization(ParkingLotSubmission, service_type: 'P'),
      inbox_scope_date_filters
    ).to_a

    # Approved parking permits are visible to the GSA_Security group for awareness.
    @submissions += apply_scope_date_filters(
      scope_group_visible(ParkingLotSubmission, status: "approved", group_name: "GSA_Security"),
      inbox_scope_date_filters
    ).to_a

    # Probation Transfer Requests - all statuses stay in inbox (except canceled)
    @submissions += apply_scope_date_filters(
      scope_by_assignee(ProbationTransferRequest, :supervisor_id).where(canceled_at: nil),
      inbox_scope_date_filters
    ).to_a

    # Critical Information Reporting forms assigned to this manager (all statuses stay in inbox)
    @submissions += apply_scope_date_filters(
      scope_by_assignee(CriticalInformationReporting, :assigned_manager_id),
      inbox_scope_date_filters
    ).to_a

    # Dynamically generated forms with approval workflows
    @submissions += fetch_dynamic_form_submissions

    # Deduplicate (a submission could match both supervisor and delegated approver).
    # Key by class + id so different form types with the same numeric id aren't collapsed.
    @submissions.uniq! { |s| [s.class, s.id] }

    # Collect unique values for filter dropdowns BEFORE in-memory filtering
    @filter_options = collect_filter_options(@submissions, inbox_field_mappings)

    # Apply in-memory filters
    @submissions = apply_filters(@submissions,
      filter_configs: inbox_filter_configs,
      date_filters: inbox_date_filters
    )

    # Apply sorting
    sort_by = params[:sort_by] || 'created_at'
    sort_direction = params[:sort_direction] || 'desc'

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

  private

  # Apply assignee-column filter based on @scoped_employee_ids.
  # nil = no restriction (system admin viewing All).
  def scope_by_assignee(model_class, column)
    @scoped_employee_ids ? model_class.where(column => @scoped_employee_ids) : model_class.all
  end

  # Pending submissions with no claimed approver yet, where one of the scoped
  # employees is in the AuthorizedApprover list for the submission's unit.
  # When @scoped_employee_ids is nil (system admin "all") every unclaimed
  # pending submission is included.
  def scope_unclaimed_by_authorization(model_class, service_type:)
    base = model_class.where(supervisor_id: nil, status: :in_progress)
    return base if @scoped_employee_ids.nil?

    units = @scoped_employee_ids.flat_map { |eid|
      AuthorizedApprover.authorized_unit_ids_for(employee_id: eid, service_type: service_type)
    }.uniq
    return model_class.none if units.empty?

    base.where(unit: units)
  end

  # Forms in a given status that members of the named group should see in their
  # inbox for awareness (e.g. approved parking permits for GSA_Security). When
  # the inbox scope is "all" (system admin, @scoped_employee_ids nil), no
  # membership filter is applied. Group is looked up by name so it works across
  # environments (group ids differ per DB).
  def scope_group_visible(model_class, status:, group_name:)
    group_id = Group.where(group_name: group_name).pick(:GroupID)
    return model_class.none unless group_id

    if @scoped_employee_ids
      member = EmployeeGroup.where(GroupID: group_id, EmployeeID: @scoped_employee_ids).exists?
      return model_class.none unless member
    end

    model_class.where(status: status)
  end

  # SQL-level date filter config
  def inbox_scope_date_filters
    [
      { param: :filter_date_from, column: :created_at, comparison: :from },
      { param: :filter_date_to, column: :created_at, comparison: :to }
    ]
  end

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
      'form_type' => ->(s) { s.class.name.demodulize.titleize },
      'name' => ->(s) { s.name.to_s },
      'unit' => ->(s) { (s.try(:unit) || '').to_s },
      'email' => ->(s) { s.email.to_s },
      'status' => ->(s) { s.status_label.to_s },
      'created_at' => ->(s) { s.created_at.to_s }
    }
  end

  # Fetch submissions from dynamically generated forms that need approval
  def fetch_dynamic_form_submissions
    submissions = []
    @copy_submission_ids ||= {}

    # Union of group_ids the scoped employees belong to. nil = system admin
    # viewing All (no restriction — every group-routed step is visible).
    scoped_group_ids = if @scoped_employee_ids.nil?
                         nil
                       else
                         EmployeeGroup.where(EmployeeID: @scoped_employee_ids).distinct.pluck(:GroupID)
                       end

    # Submitter-org values the scoped employees can stand in for. Used to
    # narrow org-filtered group routing steps to forms whose submitter shares
    # the right org level with at least one scoped employee. nil = no scope
    # restriction (system admin "all").
    submitter_org_filter = @scoped_employee_ids ? compute_submitter_org_filter(@scoped_employee_ids) : nil

    # Get all form templates that have approval workflows
    FormTemplate.where(submission_type: 'approval').find_each do |template|
      begin
        # Try to get the model class for this form template
        model_class = template.class_name.constantize
        next unless model_class.column_names.include?('approver_id')

        copy_ids = copy_submission_ids_for(model_class)
        @copy_submission_ids[model_class.name] = copy_ids if copy_ids.any?

        scope = if @scoped_employee_ids.nil?
                  # System admin viewing All — every approval form
                  model_class.all
                else
                  parts = [model_class.where(approver_id: @scoped_employee_ids)]
                  group_routing_scopes(template, model_class, scoped_group_ids, submitter_org_filter).each do |s|
                    parts << s
                  end
                  parts << model_class.where(id: copy_ids) if copy_ids.any?
                  parts.reduce(:or)
                end

        scope = apply_scope_date_filters(scope, inbox_scope_date_filters)
        submissions += scope.to_a
      rescue NameError
        # Model class doesn't exist yet (form not generated), skip it
        Rails.logger.debug "Skipping inbox query for #{template.class_name} - model not found"
      rescue => e
        Rails.logger.warn "Error querying #{template.class_name} for inbox: #{e.message}"
      end
    end

    submissions
  end

  # IDs of submissions of the given class that have an active (undismissed)
  # copy row for any of the scoped employees. Returns [] when the scope is
  # "all" (system admin) — copies in that view are best surfaced via the
  # approver/group rules so we don't artificially balloon the result set.
  def copy_submission_ids_for(model_class)
    return [] if @scoped_employee_ids.nil?
    FormSubmissionCopy
      .active
      .where(submission_type: model_class.name, recipient_employee_id: @scoped_employee_ids)
      .pluck(:submission_id)
  end

  # Returns AR scopes (one per qualifying group-routed step) on model_class
  # that should be OR'd into the inbox query. For unfiltered steps the scope
  # matches every form in step_N_pending; for org-filtered steps it also
  # narrows by the submitter-org column. Returns [] when the scoped
  # employees aren't in the step's group, or when the org filter resolves
  # to no values (e.g. submitter has no division on file).
  def group_routing_scopes(template, model_class, scoped_group_ids, submitter_org_filter)
    template.routing_steps.where(routing_type: 'group').filter_map do |step|
      next if scoped_group_ids && !scoped_group_ids.include?(step.group_id)
      status_key = "step_#{step.step_number}_pending"

      if step.org_filtered? && submitter_org_filter
        level = step.org_filter_level
        values = submitter_org_filter[level.to_sym]
        next if values.blank?
        next unless model_class.column_names.include?(level)
        model_class.where(status: status_key, level => values)
      else
        model_class.where(status: status_key)
      end
    end
  end

  # Builds the set of submitter-org values that "match" the given scoped
  # employees, per org level. For agency/division/department we look the
  # employee's Unit up in the org tables; for unit we just take the column
  # off the Employee row directly. Values are stringified to align with the
  # form tables' string org columns.
  def compute_submitter_org_filter(employee_ids)
    employees = Employee.where(employee_id: employee_ids).to_a
    unit_ids = employees.map(&:unit).compact.uniq
    units = unit_ids.any? ? Unit.where(unit_id: unit_ids).index_by { |u| u.unit_id.to_s } : {}

    filter = { agency: [], division: [], department: [], unit: [] }
    employees.each do |emp|
      unit_value = emp.unit
      filter[:unit] << unit_value.to_s if unit_value.present?

      unit = units[unit_value.to_s]
      next unless unit
      filter[:agency]     << unit.agency_id.to_s     if unit.agency_id.present?
      filter[:division]   << unit.division_id.to_s   if unit.division_id.present?
      filter[:department] << unit.department_id.to_s if unit.department_id.present?
    end

    filter.transform_values(&:uniq)
  end
end
