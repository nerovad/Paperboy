# frozen_string_literal: true

# app/helpers/submissions_helper.rb
module SubmissionsHelper
  # Returns CSS class for a status badge based on the normalized category
  # Accepts either a category symbol or a status string (for backwards compatibility)
  def status_badge_class(status_or_category)
    category = normalize_to_category(status_or_category)

    case category
    when :pending    then 'is-pending'
    when :in_review  then 'is-in-review'
    when :approved   then 'is-approved'
    when :denied     then 'is-denied'
    when :cancelled  then 'is-cancelled'
    when :scheduled  then 'is-scheduled'
    else
      'is-pending'
    end
  end

  # Returns CSS class based on category (use when you have the category directly)
  def category_badge_class(category)
    return 'is-pending' if category.nil?

    case category.to_sym
    when :pending    then 'is-pending'
    when :in_review  then 'is-in-review'
    when :approved   then 'is-approved'
    when :denied     then 'is-denied'
    when :cancelled  then 'is-cancelled'
    when :scheduled  then 'is-scheduled'
    else
      'is-pending'
    end
  end

  # Human-readable label for a category
  def category_label(category)
    {
      pending: 'Pending',
      in_review: 'In Review',
      approved: 'Approved',
      denied: 'Denied',
      cancelled: 'Cancelled',
      scheduled: 'Scheduled'
    }[category.to_sym] || 'Unknown'
  end

  # True when the viewer may change this submission's status from its detail
  # page — the form carries a status dropdown and they're allowed to use it.
  # Enforced for real by SubmissionsController#update_status.
  def can_change_submission_status?(record, routing_step: nil)
    Forms::SubmissionPolicy.status_dropdown?(record) &&
      submission_action_permitted?(record, 'change_status', routing_step: routing_step)
  end

  # True when the viewer may edit this submission. Enforced for real by
  # Forms::BaseController, which guards every form's edit/update.
  def can_edit_submission?(record, routing_step: nil)
    submission_action_permitted?(record, 'edit', routing_step: routing_step)
  end

  # True when the viewer may open this submission at all — see
  # Forms::SubmissionAccess. Enforced for real by Forms::BaseController on
  # every action that loads one submission.
  def can_view_submission?(record)
    Forms::SubmissionAccess.viewable?(
      record,
      employee_id: session.dig(:user, 'employee_id'),
      group_names: current_user_group_names,
      group_ids: current_user_group_ids,
      permission_keys: current_user_submission_action_permission_keys
    )
  end

  # Whether this record carries a comment thread -- every form does, hardcoded
  # or generated. Memoized per class so a page of rows asks once per form.
  def commentable_submission?(record)
    @commentable_classes ||= {}
    @commentable_classes.fetch(record.class) do |klass|
      @commentable_classes[klass] = SubmissionComment.commentable_class?(klass)
    end
  end

  # How many comments a submission has. Reads the page's preloaded counts
  # (InboxController) when there are any, and counts for itself otherwise.
  def comment_count_for(record)
    return SubmissionComment.on(record).count unless @comment_counts

    @comment_counts.fetch([record.class.name, record.id], 0)
  end

  # Kept in step with the comment-thread Stimulus controller, which rewrites
  # the button after a comment is posted or removed.
  def comments_button_label(count)
    count.positive? ? "Comments (#{count})" : 'Comments'
  end

  # An author may remove their own comment; a system admin may remove any.
  # Enforced for real by SubmissionCommentsController#destroy.
  def can_delete_comment?(comment)
    current_user_group_names.include?('system_admins') ||
      comment.authored_by?(session.dig(:user, 'employee_id'))
  end

  # Both buttons above ask Forms::SubmissionPolicy the same question the
  # endpoints ask, so a button a viewer can see is one they can use, and one
  # they can't see is refused if the URL is typed by hand.
  def submission_action_permitted?(record, action, routing_step: nil)
    Forms::SubmissionPolicy.permitted?(
      record,
      action: action,
      employee_id: session.dig(:user, 'employee_id'),
      group_names: current_user_group_names,
      permission_keys: current_user_submission_action_permission_keys,
      routing_step: routing_step
    )
  end

  private

  # Maps legacy status strings to categories for backwards compatibility
  def normalize_to_category(status_or_category)
    return status_or_category if status_or_category.is_a?(Symbol) && TrackableStatus::VALID_CATEGORIES.include?(status_or_category)

    status_string = status_or_category.to_s.downcase

    # Legacy status string mappings
    case status_string
    when 'submitted'
      :pending
    when 'step_1_pending', 'step_2_pending', 'step_3_pending', 'step_4_pending',
         'manager_approved', 'sent_to_security', 'sent_to_hr', 'sent_to_next', 'in_progress'
      :in_review
    when 'approved', 'step_1_approved', 'step_2_approved', 'resolved'
      :approved
    when 'denied'
      :denied
    when 'cancelled', 'canceled'
      :cancelled
    when 'scheduled'
      :scheduled
    else
      :pending
    end
  end
end
