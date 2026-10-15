# frozen_string_literal: true

module Aim
  # The review page's routing moves added for #131, beside Aim::InvoiceActions
  # (whose ACTIONS name them): an AIM Admin's Send to a queue, and the
  # high-dollar second approval -- a first approval that hands on, and the
  # second approver's Return to the first.
  module InvoiceRoutingActions
    extend ActiveSupport::Concern

    private

    # From anywhere in the pipeline to a person's queue or a shared one, by an
    # AIM Admin (#131), flagged Manual Data Entry Needed when asked.
    def send_to_queue
      return refuse('Only AIM Admins send an invoice to a queue.') unless staff?

      @invoice.send_to_queue!(params[:send_owner].to_s, actor: current_user_email, reason: reason,
                                                        manual: params[:send_manual] == '1', by: current_user_employee_id)
      finish("Sent to #{@invoice.queue_owner}#{', flagged Manual Data Entry Needed' if @invoice.manual_entry}.")
    end

    # The high-dollar second approval (#131): this approval is the first.
    def second_approval_first
      @invoice.first_approve!(actor: current_user_email, by: current_user_employee_id)
      finish("First approval recorded. It is over the BU's amount, so it goes to " \
             "#{@invoice.second_approval_setting.second_approver_name} for a second approval.")
    end

    def return_to_first
      return refuse('Only its second approver can return it.') unless @invoice.awaiting_second_approval? &&
                                                                      @invoice.second_approver?(current_user_employee_id, staff: staff?)

      @invoice.return_to_first_approver!(actor: current_user_email, reason: reason, by: current_user_employee_id)
      finish('Returned to the first approver.')
    end
  end
end
