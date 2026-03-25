# app/controllers/inbox_controller.rb
class InboxController < ApplicationController
  include Filterable
  include Pagy::Method

  def queue
    employee = session[:user]
    return @submissions = [] unless employee.present? && employee["employee_id"].present?

    employee_id = employee["employee_id"].to_s
    @submissions = []

    # Parking Lot Submissions where employee is either:
    # 1. Supervisor (Dept Head) - all statuses stay in inbox
    # 2. Delegated Approver - all statuses stay in inbox
    @submissions += apply_scope_date_filters(
      ParkingLotSubmission.where(supervisor_id: employee_id),
      inbox_scope_date_filters
    ).to_a
    @submissions += apply_scope_date_filters(
      ParkingLotSubmission.where(delegated_approver_id: employee_id),
      inbox_scope_date_filters
    ).to_a

    # Probation Transfer Requests - all statuses stay in inbox (except canceled)
    @submissions += apply_scope_date_filters(
      ProbationTransferRequest.where(supervisor_id: employee_id, canceled_at: nil),
      inbox_scope_date_filters
    ).to_a

    # Critical Information Reporting forms assigned to this manager (all statuses stay in inbox)
    @submissions += apply_scope_date_filters(
      CriticalInformationReporting.where(assigned_manager_id: employee_id),
      inbox_scope_date_filters
    ).to_a

    # Dynamically generated forms with approval workflows
    @submissions += fetch_dynamic_form_submissions(employee_id)

    # Deduplicate (a submission could match both supervisor and delegated approver)
    @submissions.uniq!(&:id)

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

    # Load employees for reassignment dropdown
    @employees = Employee.order(:last_name, :first_name)
  end

  private

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
  def fetch_dynamic_form_submissions(employee_id)
    submissions = []

    # Get all form templates that have approval workflows
    FormTemplate.where(submission_type: 'approval').find_each do |template|
      begin
        # Try to get the model class for this form template
        model_class = template.class_name.constantize

        # Query for submissions where this employee is the approver
        if model_class.column_names.include?('approver_id')
          scope = model_class.where(approver_id: employee_id)
          scope = apply_scope_date_filters(scope, inbox_scope_date_filters)
          submissions += scope.to_a
        end
      rescue NameError
        # Model class doesn't exist yet (form not generated), skip it
        Rails.logger.debug "Skipping inbox query for #{template.class_name} - model not found"
      rescue => e
        Rails.logger.warn "Error querying #{template.class_name} for inbox: #{e.message}"
      end
    end

    submissions
  end
end
