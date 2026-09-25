# frozen_string_literal: true

module Aim
  # The signed-in person's invoices that are ready for them: Ready for
  # Approval, assigned to their employee id. This is where people approve,
  # send back and move their invoices; everything earlier is AIM staff's.
  class MyQueueController < BaseController
    before_action :remember_queue_page, only: :index

    def index
      @employee_id = current_user_employee_id
      @queue = 'ready_for_approval'
      @invoices = @employee_id ? Aim::Invoice.owned_by(@employee_id).in_queue(@queue).newest_first.to_a : []
    end
  end
end
