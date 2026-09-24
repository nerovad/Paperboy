# frozen_string_literal: true

module Aim
  # The signed-in person's own invoices: everything open whose owner is their
  # employee id, grouped by where it stands. This is where people approve and
  # move their invoices. AIM v2.
  class MyQueueController < BaseController
    def index
      @employee_id = current_user_employee_id
      invoices = open_invoices_for(@employee_id)
      @queue = 'ready_for_approval'
      @groups = invoices.group_by(&:queue).sort_by { |queue, _| Aim::Invoice::QUEUES.keys.index(queue) || 99 }
                        .map { |queue, rows| [helpers.aim_queue_label(queue), rows] }
    end

    private

    def open_invoices_for(employee_id)
      return [] if employee_id.nil?

      Aim::Invoice.owned_by(employee_id).where.not(state: Aim::Invoice::TERMINAL_STATES).newest_first.to_a
    end
  end
end
