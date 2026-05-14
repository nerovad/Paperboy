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
      @filter_employees = @is_system_admin ? @employees : Employee.where(EmployeeID: @subordinate_ids).order(:last_name, :first_name)
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
    base = model_class.where(supervisor_id: nil, status: 0)
    return base if @scoped_employee_ids.nil?

    units = @scoped_employee_ids.flat_map { |eid|
      AuthorizedApprover.authorized_unit_ids_for(employee_id: eid, service_type: service_type)
    }.uniq
    return model_class.none if units.empty?

    base.where(unit: units)
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

    # Union of group_ids the scoped employees belong to. nil = system admin
    # viewing All (no restriction — every group-routed step is visible).
    scoped_group_ids = if @scoped_employee_ids.nil?
                         nil
                       else
                         EmployeeGroup.where(EmployeeID: @scoped_employee_ids).distinct.pluck(:GroupID)
                       end

    # Get all form templates that have approval workflows
    FormTemplate.where(submission_type: 'approval').find_each do |template|
      begin
        # Try to get the model class for this form template
        model_class = template.class_name.constantize
        next unless model_class.column_names.include?('approver_id')

        group_status_keys = group_routed_status_keys(template, scoped_group_ids)

        scope = if @scoped_employee_ids.nil?
                  # System admin viewing All — every approval form
                  model_class.all
                else
                  by_approver = model_class.where(approver_id: @scoped_employee_ids)
                  if group_status_keys.any?
                    by_approver.or(model_class.where(status: group_status_keys))
                  else
                    by_approver
                  end
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

  # Status keys (e.g. "step_2_pending") for routing steps that route to a group
  # the scoped employees are in. When scoped_group_ids is nil, all group-routed
  # steps qualify (system admin viewing All).
  def group_routed_status_keys(template, scoped_group_ids)
    template.routing_steps.where(routing_type: 'group').filter_map do |step|
      next if scoped_group_ids && !scoped_group_ids.include?(step.group_id)
      "step_#{step.step_number}_pending"
    end
  end
end
