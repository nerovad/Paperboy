# Alerts the form's creator and system admins when a submission reaches a
# routing step that has no eligible approver, so it doesn't sit silently stuck.
class StuckSubmissionMailer < ApplicationMailer
  def no_eligible_approver(submission_class, submission_id, step_id)
    @submission = resolve_submission(submission_class, submission_id)
    return if @submission.nil?

    @step = FormTemplateRoutingStep.find_by(id: step_id)
    return if @step.nil?

    @template = @step.form_template
    @form_name = @template&.name || submission_class.to_s.underscore.humanize.titleize
    @step_label = @step.routing_label

    recipients = (creator_email(@template) + system_admin_emails).compact.uniq
    return if recipients.blank?

    mail(
      to: recipients,
      subject: "Action needed: #{@form_name} ##{submission_id} has no approver at step #{@step.step_number}"
    )
  end

  private

  def resolve_submission(submission_class, submission_id)
    submission_class.to_s.constantize.find_by(id: submission_id)
  rescue NameError
    nil
  end

  def creator_email(template)
    return [] unless template&.created_by.present?
    [ Employee.find_by(employee_id: template.created_by)&.email ]
  end

  def system_admin_emails
    grp = Group.where("LOWER(Group_Name) = ?", "system_admins").first
    return [] unless grp
    ids = EmployeeGroup.where(GroupID: grp.GroupID).pluck(:EmployeeID)
    Employee.where(id: ids).pluck(:email)
  rescue StandardError
    []
  end
end
