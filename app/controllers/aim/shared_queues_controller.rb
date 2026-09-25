# frozen_string_literal: true

module Aim
  # The shared queues of the budget units you cover: ready invoices nobody
  # owns yet, one group per BU. From here people open, approve and claim them
  # (Claim moves one into your queue). Personal for everyone, AIM Admins too
  # (Joshua, 2026-09-25): an admin's view of every BU is the Pipeline's Ready
  # for Approval and By BU.
  class SharedQueuesController < BaseController
    before_action :remember_queue_page, only: :index

    def index
      @queue = 'ready_for_approval'
      @budget_units = Aim::Users.shared_budget_units(current_user_employee_id, staff: false)
      invoices = Aim::Invoice.shared_for(@budget_units).newest_first.to_a
      coa = Aim::Units.new
      @groups = invoices.group_by(&:budget_unit).sort_by { |bu, _| bu.to_s }
                        .map { |bu, rows| ["#{coa.label(bu)} shared queue", rows] }
    end
  end
end
