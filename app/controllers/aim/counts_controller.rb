# frozen_string_literal: true

module Aim
  # The sidebar, dashboard and My Queue counts, fetched after the page has
  # drawn (aim_counts_controller.js) so no screen waits on them. A database
  # that cannot be reached leaves the counts blank rather than failing.
  # scope=mine asks for My Queue's count alone: the Invoices tab on My Work
  # and the name badge ask on every page, and need nothing more.
  class CountsController < BaseController
    def show
      return render json: { my_queue: my_queue_count } if params[:scope] == 'mine'

      units = Aim::Users.shared_budget_units(current_user_employee_id, staff: false)
      counts = { my_queue: my_queue_count, shared_queues: Aim::Invoice.shared_for(units).count }
      counts[:queues] = Aim::Invoice.queue_counts if helpers.aim_queue_access?
      counts[:queues] = (counts[:queues] || {}).merge(Aim::FiscalRecord.status_counts) if helpers.aim_fiscal?
      render json: counts
    rescue StandardError => e
      Rails.logger.error "AIM could not count its queues: #{e.message}"
      render json: {}, status: :service_unavailable
    end

    private

    def my_queue_count
      id = current_user_employee_id
      id ? Aim::Invoice.owned_by(id).in_queue('ready_for_approval').count : 0
    end
  end
end
