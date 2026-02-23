class HelpTicketsController < ApplicationController
  def new
  end

  def create
    HelpTicketMailer.ticket_submitted(
      subject: params[:subject],
      description: params[:description],
      user_name: "#{current_user.first_name} #{current_user.last_name}",
      user_email: current_user.email,
      employee_id: current_user.employee_id
    ).deliver_later

    redirect_to form_success_path
  end
end
