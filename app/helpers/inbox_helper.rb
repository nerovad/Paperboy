module InboxHelper
  # Known hardcoded form types that have custom handling
  HARDCODED_FORM_TYPES = %w[
    CriticalInformationReporting
    ProbationTransferRequest
  ].freeze

  # Filter params on the inbox queue. Used both for the "Clear Filters" link and
  # to tell a genuinely-cleared inbox ("Inbox Zero!") apart from a filter that
  # simply matched nothing.
  INBOX_FILTER_PARAMS = %i[
    filter_reference filter_form_type filter_unit
    filter_status filter_date_from filter_date_to filter_employee
  ].freeze

  def inbox_filters_active?
    INBOX_FILTER_PARAMS.any? { |key| params[key].present? }
  end

  # Look up the FormTemplate for a given submission
  # Returns nil for hardcoded forms or if no template exists
  def form_template_for(submission)
    class_name = submission.class.name
    return nil if HARDCODED_FORM_TYPES.include?(class_name)

    @form_template_cache ||= {}
    @form_template_cache[class_name] ||= FormTemplate.find_by(class_name: class_name)
  end

  # Check if a submission is from a dynamically generated form
  def dynamic_form?(submission)
    !HARDCODED_FORM_TYPES.include?(submission.class.name)
  end

  # Human-facing reference number for a submission, e.g. "LOA-1042". Memoizes
  # the class_name => prefix map so rendering a page of rows is a single query.
  def inbox_reference(submission)
    @prefix_map ||= FormReference.prefix_map
    FormReference.reference_for(submission, @prefix_map)
  end

  # Check if a button should be shown for this submission
  def show_inbox_button?(submission, button_type)
    template = form_template_for(submission)
    return false unless template

    step = current_routing_step_for(submission, template)
    return step.has_inbox_button?(button_type) if step

    template.has_inbox_button?(button_type)
  end

  # Find the routing step a submission is currently sitting at, based on its
  # `step_N_pending` status. Returns nil for non-routed forms or unmatched
  # statuses; callers should fall back to the template-level buttons.
  def current_routing_step_for(submission, template = nil)
    template ||= form_template_for(submission)
    return nil unless template
    status = submission.respond_to?(:status) ? submission.status.to_s : ''
    match = status.match(/\Astep_(\d+)_pending\z/)
    return nil unless match
    template.routing_steps.find_by(step_number: match[1].to_i)
  end

  # The active (undismissed) FormSubmissionCopy this submission represents
  # for the current viewer, or nil if the viewer isn't a copy recipient.
  # Looked up against @copy_submission_ids prepopulated by InboxController.
  def copy_row_for(submission)
    ids_by_class = @copy_submission_ids
    return nil unless ids_by_class.is_a?(Hash)
    ids = ids_by_class[submission.class.name]
    return nil unless ids&.include?(submission.id)
    employee_id = session.dig(:user, "employee_id").to_s
    return nil if employee_id.blank?
    @copy_rows_cache ||= {}
    @copy_rows_cache[[submission.class.name, submission.id]] ||=
      FormSubmissionCopy.active.find_by(
        submission_type: submission.class.name,
        submission_id: submission.id,
        recipient_employee_id: employee_id
      )
  end

  # Get the PDF path for any submission type
  def inbox_pdf_path(submission)
    case submission
    when CriticalInformationReporting
      pdf_critical_information_reporting_path(submission)
    when ParkingLotSubmission
      pdf_parking_lot_submission_path(submission)
    when ProbationTransferRequest
      pdf_probation_transfer_request_path(submission)
    else
      # For dynamic forms, try to construct the path
      polymorphic_path(submission, action: :pdf)
    end
  rescue
    nil
  end

  # Get the edit path for any submission type
  def inbox_edit_path(submission)
    case submission
    when CriticalInformationReporting
      edit_critical_information_reporting_path(submission)
    else
      # For dynamic forms, try to construct the path
      edit_polymorphic_path(submission)
    end
  rescue
    nil
  end

  # Get the approve path for any submission type
  def inbox_approve_path(submission)
    polymorphic_path(submission, action: :approve)
  rescue
    nil
  end

  # Get the deny path for any submission type
  def inbox_deny_path(submission)
    polymorphic_path(submission, action: :deny)
  rescue
    nil
  end

  # Get the update_status path for any submission type
  def inbox_update_status_path(submission)
    polymorphic_path(submission, action: :update_status)
  rescue
    nil
  end

  # Get available status options for a submission
  def inbox_status_options(submission)
    if submission.class.respond_to?(:statuses)
      labels = submission.class.const_defined?(:STATUS_LABELS) ? submission.class::STATUS_LABELS : {}
      submission.class.statuses.keys.map do |status|
        label = labels[status.to_sym] || status.to_s.tr('_', ' ').titleize
        [label, status]
      end
    else
      []
    end
  end
end
