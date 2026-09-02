# frozen_string_literal: true

# Tells one approver that a submission has landed in their inbox and is waiting
# on them. Fired from TrackableStatus at each point a form arrives on a routing
# step, once per eligible approver who has switched on "Inbox notifications"
# under Settings.
#
# One mail per recipient rather than one mail to the pool: the opt-in is
# per-person, and a group step's approver list is not something to disclose in a
# To: header. Everything is resolved by id so async delivery sees committed data.
class InboxNotificationMailer < ApplicationMailer
  def pending_approval(submission_class, submission_id, step_id, employee_id)
    @approver = Employee.find_by(id: employee_id.to_s)
    return if @approver.nil? || @approver.email.blank?

    @submission = resolve_submission(submission_class, submission_id)
    return if @submission.nil?

    @step = Forms::TemplateRoutingStep.find_by(id: step_id)
    @form_name = FormEmailRenderer.form_name(@submission)
    @reference = Forms::Reference.reference_for(@submission) || "##{@submission.id}"

    mail(to: @approver.email, subject: "Awaiting your approval: #{@form_name} #{@reference}")
  end

  private

  def resolve_submission(submission_class, submission_id)
    submission_class.to_s.constantize.find_by(id: submission_id)
  rescue NameError
    nil
  end
end
