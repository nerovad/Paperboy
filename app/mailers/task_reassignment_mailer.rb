# app/mailers/task_reassignment_mailer.rb

class TaskReassignmentMailer < ApplicationMailer
  default from: "gsa-forms@ventura.org"

  def reassignment_notification(task_reassignment_id)
    @reassignment = TaskReassignment.find(task_reassignment_id)
    @task = @reassignment.task
    @to_employee = @reassignment.to_employee
    @from_employee = @reassignment.from_employee
    @reassigned_by = @reassignment.reassigned_by_employee

    # Determine task type for subject
    task_type = @task.class.name.demodulize.titleize

    mail(
      to: @to_employee.EE_Email,
      subject: "Task Reassigned to You: #{task_type} ##{@task.id}"
    )
  end

  def take_back_notification(task_reassignment_id)
    @reassignment = TaskReassignment.find(task_reassignment_id)
    @task = @reassignment.task
    @to_employee = @reassignment.to_employee
    @from_employee = @reassignment.from_employee

    # Determine task type for subject
    task_type = @task.class.name.demodulize.titleize

    mail(
      to: @to_employee.EE_Email,
      subject: "Task Returned to You: #{task_type} ##{@task.id}"
    )
  end
end
