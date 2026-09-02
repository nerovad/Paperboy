# frozen_string_literal: true

# Mail for people following a form type rather than owning a submission — see
# Forms::Subscription. Two shapes of the same information: `activity` for
# immediate subscribers, one message per event, and `daily_digest` for the rest,
# one message per day.
#
# Everything resolves by id so async delivery sees committed data.
class FormSubscriptionMailer < ApplicationMailer
  helper_method :reference_label, :form_label, :column_label

  def activity(submission_class, submission_id, event, employee_id, edit_ids = [])
    @employee = Employee.find_by(id: employee_id.to_s)
    return if @employee.nil? || @employee.email.blank?

    @submission = resolve_submission(submission_class, submission_id)
    return if @submission.nil?

    @event = event.to_s
    @form_name = FormEmailRenderer.form_name(@submission)
    @reference = Forms::Reference.reference_for(@submission) || "##{@submission.id}"
    @edits = RecordEdit.where(id: Array(edit_ids)).order(:created_at).to_a
    @status_change = latest_status_change if @event == 'status_changed'

    mail(to: @employee.email, subject: activity_subject)
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

  def form_label(record_type) = record_type.to_s.demodulize.titleize

  def column_label(column_name) = column_name.to_s.humanize

  private

  def activity_subject
    case @event
    when 'created' then "New #{@form_name} #{@reference}"
    when 'edited' then "Updated: #{@form_name} #{@reference}"
    when 'status_changed' then "Status changed: #{@form_name} #{@reference}"
    else "#{@form_name} #{@reference}"
    end
  end

  # The transition this mail is about. Read back rather than passed in so the
  # mail renders the labels StatusChange stored, not raw enum values.
  def latest_status_change
    @submission.status_changes.reverse_chronological.first
  rescue StandardError
    nil
  end

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
