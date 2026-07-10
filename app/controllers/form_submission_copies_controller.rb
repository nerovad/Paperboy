class FormSubmissionCopiesController < ApplicationController
  def dismiss
    copy = FormSubmissionCopy.find(params[:id])
    employee_id = session.dig(:user, 'employee_id').to_s
    unless copy.recipient_employee_id.to_s == employee_id
      redirect_to inbox_queue_path, alert: 'Not your copy to dismiss.'
      return
    end

    copy.dismiss!
    redirect_to inbox_queue_path, notice: 'Copy dismissed.'
  end
end
