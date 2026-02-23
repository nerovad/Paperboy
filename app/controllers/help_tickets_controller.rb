class HelpTicketsController < ApplicationController
  helper_method :ticket_admin?

  def index
    employee_id = session.dig(:user, "employee_id")
    @my_tickets = HelpTicket.for_employee(employee_id).order(created_at: :desc)
    @all_tickets = HelpTicket.order(created_at: :desc) if ticket_admin?
  end

  def show
    @help_ticket = HelpTicket.find(params[:id])
    employee_id = session.dig(:user, "employee_id").to_s

    unless @help_ticket.employee_id == employee_id || ticket_admin?
      redirect_to help_tickets_path, alert: "Access denied."
    end
  end

  def new
  end

  def create
    @help_ticket = HelpTicket.new(
      subject: params[:subject],
      description: params[:description],
      employee_id: current_user.employee_id,
      employee_name: "#{current_user.first_name} #{current_user.last_name}",
      employee_email: current_user.email
    )

    if @help_ticket.save
      HelpTicketMailer.ticket_submitted(
        subject: @help_ticket.subject,
        description: @help_ticket.description,
        user_name: @help_ticket.employee_name,
        user_email: @help_ticket.employee_email,
        employee_id: @help_ticket.employee_id
      ).deliver_later

      redirect_to help_tickets_path, notice: "Ticket submitted successfully.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def close
    @help_ticket = HelpTicket.find(params[:id])

    unless ticket_admin?
      redirect_to help_tickets_path, alert: "Access denied."
      return
    end

    @help_ticket.closed!
    redirect_to help_ticket_path(@help_ticket), notice: "Ticket closed.", status: :see_other
  end

  private

  def ticket_admin?
    current_user_group_names.include?("ticket_admin")
  end
end
