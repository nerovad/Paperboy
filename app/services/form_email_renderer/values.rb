# frozen_string_literal: true

class FormEmailRenderer
  # Token => how to read it. Each reader runs on the renderer (instance_exec),
  # so it sees the submission, the caller's context and the renderer's own
  # lookups. {{field.*}} is handled apart (see #field_value); a token missing
  # here renders blank.
  module Values
    READERS = {
      'submitter_name' => -> { submission.try(:name) },
      'submitter_email' => -> { submission.try(:email) },
      'form_name' => -> { FormEmailRenderer.form_name(submission) },
      'status_label' => -> { submission.try(:status_label) },
      'deny_reason' => -> { submission.try(:deny_reason) || submission.try(:denial_reason) },
      'reference' => -> { reference },
      'url' => -> { url },
      'link' => -> { url },
      'submitted_at' => -> { submission.try(:created_at)&.strftime(TIME_FORMAT) },
      # An email rule can go to several people at once, so there may be no
      # one name to use: "Hello there," rather than "Hello ,".
      'recipient_first_name' => -> { context[:recipient_first_name].presence || 'there' },
      'approval_step' => -> { context[:approval_step] },
      'from_status' => -> { context.fetch(:from_status) { status_change&.from_status } },
      'to_status' => -> { context.fetch(:to_status) { status_change&.to_status } },
      'changed_by' => -> { context.fetch(:changed_by) { status_change&.changed_by_name } }
    }.freeze
  end
end
