module InboxHelper
  # Known hardcoded form types that have custom handling
  HARDCODED_FORM_TYPES = %w[
    CriticalInformationReporting
    ParkingLotSubmission
    ProbationTransferRequest
  ].freeze

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

  # Check if a button should be shown for this submission
  def show_inbox_button?(submission, button_type)
    template = form_template_for(submission)
    return false unless template

    template.has_inbox_button?(button_type)
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
      submission.class.statuses.keys.map do |status|
        [status.to_s.tr('_', ' ').titleize, status]
      end
    else
      []
    end
  end
end
