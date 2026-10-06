# frozen_string_literal: true

# Mail for people following a form type rather than owning a submission — see
# Forms::Subscription. Two shapes of the same information: `activity` and
# `comment` for immediate subscribers, one message per event, and
# `daily_digest` for the rest, one message per day.
#
# Everything resolves by id so async delivery sees committed data.
class FormSubscriptionMailer < ApplicationMailer
  helper_method :reference_label, :reference_url, :form_label, :column_label

  # Subscription event => which of the form's emails (Forms::TemplateEmail)
  # words it. The digest spans many forms, so it keeps its own layout.
  EVENT_EMAILS = {
    'created' => 'new_submission',
    'edited' => 'field_edited',
    'status_changed' => 'status_changed'
  }.freeze

  def activity(submission_class, submission_id, event, employee_id, edit_ids = [])
    @employee = Employee.find_by(id: employee_id.to_s)
    return if @employee.nil? || @employee.email.blank?

    @submission = resolve_submission(submission_class, submission_id)
    return if @submission.nil?

    edits = RecordEdit.where(id: Array(edit_ids)).order(:created_at).to_a
    email = Forms::TemplateEmail.for(@submission, EVENT_EMAILS.fetch(event.to_s, 'new_submission'))
    context = { recipient_first_name: @employee.first_name }
    if edits.any?
      context[:changes] = edits
      context[:changed_by] = edits.map(&:changed_by_name).compact_blank.first
    end

    @form_name = FormEmailRenderer.form_name(@submission)
    @body_html = email.render_body(@submission, context)
    mail(to: @employee.email, subject: email.render_subject(@submission, context))
  end

  # Somebody commented on a submission. Its own layout rather than one of the
  # form's customizable emails: the message is the comment, not the form.
  def comment(comment_id, employee_id)
    @employee = Employee.find_by(id: employee_id.to_s)
    return if @employee.nil? || @employee.email.blank?

    @comment = SubmissionComment.find_by(id: comment_id)
    @submission = @comment&.commentable
    return if @submission.nil?

    @form_name = FormEmailRenderer.form_name(@submission)
    @reference = Forms::Reference.reference_for(@submission).presence || "##{@submission.id}"
    @submission_url = FormEmailRenderer.submission_url(@submission)

    mail(to: @employee.email, subject: "New comment on #{@form_name} #{@reference}")
  end

  def daily_digest(employee_id, since, through)
    @employee = Employee.find_by(id: employee_id.to_s)
    return if @employee.nil? || @employee.email.blank?

    @digest = Forms::SubscriptionDigest.new(employee_id: employee_id, since: since, through: through)
    return unless @digest.any?

    @prefix_map = Forms::Reference.prefix_map
    count = @digest.total_events

    mail(to: @employee.email,
         subject: "Form activity digest: #{count} #{'change'.pluralize(count)} #{digest_day}")
  end

  # A digest lists rows from several tables, and only has each row's type and
  # id. These turn that pair into the same wording the rest of the app uses.
  def reference_label(record_type, record_id)
    model = record_type.to_s.safe_constantize
    prefix = model ? Forms::Reference.prefix_for(model, @prefix_map) : nil
    prefix.present? ? "#{prefix}-#{record_id}" : "#{form_label(record_type)} ##{record_id}"
  end

  # Where a digest row's submission lives, found the same way the per-event
  # emails find it. Nil when the row has gone, so the view prints plain text.
  def reference_url(record_type, record_id)
    model = record_type.to_s.safe_constantize
    return unless model.is_a?(Class) && model < ActiveRecord::Base

    record = model.find_by(id: record_id)
    record && FormEmailRenderer.submission_url(record).presence
  rescue StandardError
    nil
  end

  def form_label(record_type) = record_type.to_s.demodulize.titleize

  def column_label(column_name) = column_name.to_s.humanize

  private

  def digest_day
    return @digest.since.to_date.strftime('for %b %-d') if @digest.since.respond_to?(:to_date)

    ''
  end

  def resolve_submission(submission_class, submission_id)
    submission_class.to_s.constantize.find_by(id: submission_id)
  rescue NameError
    nil
  end
end
