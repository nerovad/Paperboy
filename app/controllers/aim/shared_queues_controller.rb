# frozen_string_literal: true

module Aim
  # The shared queues of the budget units you cover: ready invoices nobody
  # owns yet, one group per BU. From here people open, approve and claim them
  # (Claim moves one into your queue). Which BUs you cover is
  # Aim::Users.shared_budget_units until the Admin page sets it.
  class SharedQueuesController < BaseController
    def index
      @queue = 'ready_for_approval'
      staff = helpers.aim_queue_access?
      @budget_units = Aim::Users.shared_budget_units(current_user_employee_id, staff: staff)
      invoices = Aim::Invoice.shared_for(@budget_units).newest_first.to_a
      @groups = invoices.group_by(&:budget_unit).sort_by { |bu, _| bu.to_s }
                        .map { |bu, rows| ["#{bu.presence || 'No BU'} shared queue", rows] }
    end
  end
end
