class HelpController < ApplicationController
  helper_method :ticket_admin?

  def index
    @active_tab = params[:tab].presence || "documentation"
    employee_id = session.dig(:user, "employee_id")
    @my_tickets = HelpTicket.for_employee(employee_id).order(created_at: :desc)
    @all_tickets = HelpTicket.order(created_at: :desc) if ticket_admin?
  end

  private

  def ticket_admin?
    current_user_group_names.include?("ticket_admin")
  end
end
