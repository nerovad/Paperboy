# Assembles the set of submissions that make up a user's inbox — the single
# source of truth shared by InboxController#queue (which then text-filters,
# sorts, and paginates) and the profile/tab badge counter (which just needs the
# count). Because both go through this one query, the badge can never drift
# from what the inbox actually shows.
class InboxQuery
  # scoped_employee_ids: employee ids whose inbox to assemble, or nil for "no
  #                      assignee restriction" (system admin viewing All).
  # viewer_form_types:   class names the viewer holds a visibility grant for;
  #                      only surfaced when filter_form_type names that type.
  # filter_form_type:    the form-type filter currently applied (titleized,
  #                      demodulized class name), or nil.
  # date_from / date_to: optional ISO date strings bounding created_at.
  def initialize(scoped_employee_ids:, viewer_form_types: [], filter_form_type: nil, date_from: nil, date_to: nil)
    @scoped_employee_ids = scoped_employee_ids
    @viewer_form_types = viewer_form_types || []
    @filter_form_type = filter_form_type.presence
    @date_from = date_from.presence
    @date_to = date_to.presence
    @copy_submission_ids = {}
  end

  # FormSubmissionCopy ids surfaced per model class — consumed by the inbox
  # view's dynamic-button partial. Populated as a side effect of #submissions.
  attr_reader :copy_submission_ids

  # The deduped, non-terminal submissions in scope, before the inbox's in-memory
  # text filters, sorting, and pagination.
  def submissions
    items = []

    # Probation Transfer Requests — all statuses stay in the inbox except canceled.
    items += apply_date_filters(
      scope_by_assignee(ProbationTransferRequest, :supervisor_id).where(canceled_at: nil)
    ).to_a

    # Critical Information Reporting forms assigned to this manager.
    items += apply_date_filters(
      scope_by_assignee(CriticalInformationReporting, :assigned_manager_id)
    ).to_a

    # Dynamically generated approval forms (approver / group / authorization / copies).
    items += dynamic_form_submissions

    # Visibility-granted form types — every submission, but only when the viewer
    # has filtered the inbox to that exact form type.
    @viewer_form_types.each do |class_name|
      model = class_name.safe_constantize
      next unless model.is_a?(Class) && model < ActiveRecord::Base

      items += granted_submissions(model).to_a
    rescue StandardError => e
      Rails.logger.warn "Inbox visibility grant query failed for #{class_name}: #{e.message}"
    end

    # Deduplicate (a submission could match several rules). Key by class + id so
    # different form types that share a numeric id aren't collapsed.
    items.uniq! { |s| [s.class, s.id] }

    # The inbox is a work queue, not an archive: drop anything that has reached
    # an end state (per each form's is_end status flags). This also clears the
    # actioning approver's lingering copy of finished dynamic-form approvals.
    items.reject! { |s| s.respond_to?(:terminal?) && s.terminal? }

    items
  end

  # Number of items in the inbox. This assembles the records (the only accurate
  # way — terminal status is resolved in Ruby), so it's the same work the page
  # does and cannot disagree with it.
  def count
    submissions.size
  end

  private

  # SQL-level created_at bounds, matching the inbox's date filter semantics.
  def apply_date_filters(scope)
    scope = scope.where(created_at: Date.parse(@date_from).beginning_of_day..) if @date_from
    scope = scope.where(created_at: ..Date.parse(@date_to).end_of_day) if @date_to
    scope
  rescue ArgumentError
    # Unparseable date param — ignore the bound rather than blow up the inbox.
    scope
  end

  # Assignee-column scope. nil scope = no restriction (system admin viewing All).
  def scope_by_assignee(model_class, column)
    @scoped_employee_ids ? model_class.where(column => @scoped_employee_ids) : model_class.all
  end

  # Every submission of a granted form type — but only when the viewer has
  # filtered to that exact type. Membership (whether they hold the grant) is
  # already enforced by @viewer_form_types; this guards the "only when filtered"
  # rule.
  def granted_submissions(model)
    return model.none unless @filter_form_type == model.name.demodulize.titleize

    apply_date_filters(model.all)
  end

  # Submissions from dynamically generated forms that need approval.
  def dynamic_form_submissions
    submissions = []

    # Union of group_ids the scoped employees belong to. nil = system admin
    # viewing All (no restriction — every group-routed step is visible).
    scoped_group_ids = if @scoped_employee_ids.nil?
                         nil
                       else
                         EmployeeGroup.where(EmployeeID: @scoped_employee_ids).distinct.pluck(:GroupID)
                       end

    # Submitter-org values the scoped employees can stand in for. Used to narrow
    # org-filtered group routing steps. nil = no scope restriction.
    submitter_org_filter = @scoped_employee_ids ? compute_submitter_org_filter(@scoped_employee_ids) : nil

    FormTemplate.where(submission_type: 'approval').find_each do |template|
      model_class = template.class_name.constantize
      next unless model_class.column_names.include?('approver_id')

      copy_ids = copy_submission_ids_for(model_class)
      @copy_submission_ids[model_class.name] = copy_ids if copy_ids.any?

      scope = if @scoped_employee_ids.nil?
                # System admin viewing All — every approval form.
                model_class.all
              else
                parts = [model_class.where(approver_id: @scoped_employee_ids)]
                group_routing_scopes(template, model_class, scoped_group_ids, submitter_org_filter).each do |s|
                  parts << s
                end
                authorization_routing_scopes(template, model_class, @scoped_employee_ids).each do |s|
                  parts << s
                end
                parts << model_class.where(id: copy_ids) if copy_ids.any?
                parts.reduce(:or)
              end

      scope = apply_date_filters(scope)
      submissions += scope.to_a
    rescue NameError
      # Model class doesn't exist yet (form not generated), skip it.
      Rails.logger.debug "Skipping inbox query for #{template.class_name} - model not found"
    rescue StandardError => e
      Rails.logger.warn "Error querying #{template.class_name} for inbox: #{e.message}"
    end

    submissions
  end

  # IDs of submissions of the given class with an active (undismissed) copy row
  # for any scoped employee. Returns [] when scope is "all" (system admin).
  def copy_submission_ids_for(model_class)
    return [] if @scoped_employee_ids.nil?

    FormSubmissionCopy
      .active
      .where(submission_type: model_class.name, recipient_employee_id: @scoped_employee_ids)
      .pluck(:submission_id)
  end

  # AR scopes (one per qualifying group-routed step) to OR into the query.
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

  # AR scopes (one per authorization-routed step) to OR into the query. A
  # submission at an authorization step is visible to a scoped employee when its
  # budget unit is one they're authorized to approve for the step's service type.
  def authorization_routing_scopes(template, model_class, scoped_employee_ids)
    return [] if scoped_employee_ids.nil?
    return [] unless model_class.column_names.include?('unit')

    template.routing_steps.where(routing_type: 'authorization').filter_map do |step|
      service_type = step.authorization_service_type
      next if service_type.blank?

      authorized_units = scoped_employee_ids.flat_map do |eid|
        AuthorizedApprover.authorized_unit_ids_for(employee_id: eid, service_type: service_type)
      end.uniq
      next if authorized_units.empty?

      model_class.where(status: "step_#{step.step_number}_pending", unit: authorized_units)
    end
  end

  # Builds the set of submitter-org values that "match" the given scoped
  # employees, per org level, so org-filtered routing steps can be narrowed.
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
