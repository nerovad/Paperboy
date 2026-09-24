# frozen_string_literal: true

module Aim
  # AIM staff work every invoice. Anyone else works only the invoices in
  # their own queue that are ready for them, and only with an owner's
  # actions: save, approve, send back, reject, move.
  module InvoiceAccess
    extend ActiveSupport::Concern

    OWNER_ACTIONS = ['Save Changes', 'Approve', 'Send Back', 'Reject', 'Unclaim'].freeze

    private

    def require_staff_or_owner
      return if helpers.aim_queue_access?
      return deny_owner unless @invoice.state == 'ready_for_approval' &&
                               @invoice.assigned_employee_id.present? &&
                               @invoice.assigned_employee_id == current_user_employee_id
      return if action_name != 'update' || OWNER_ACTIONS.include?(params[:commit].to_s)

      deny_owner
    end

    def home_queue_path = helpers.aim_queue_access? ? aim_invoices_path(queue: @queue) : aim_my_queue_path

    def deny_owner
      redirect_to aim_my_queue_path, alert: 'That invoice is not in your queue.'
    end
  end
end
