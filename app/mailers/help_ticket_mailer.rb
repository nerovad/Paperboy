class HelpTicketMailer < ApplicationMailer
  def ticket_submitted(subject:, description:, user_name:, user_email:, employee_id:)
    @description = description
    @user_name = user_name
    @user_email = user_email
    @employee_id = employee_id

    mail(
      to: "matthew.davoren@ventura.org",
      reply_to: user_email,
      subject: subject
    )
  end
end
