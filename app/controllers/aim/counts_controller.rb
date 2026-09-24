# frozen_string_literal: true

module Aim
  # The sidebar, dashboard and My Queue counts, fetched after the page has
  # drawn (aim_counts_controller.js) so no screen waits on them. A database
  # that cannot be reached leaves the counts blank rather than failing.
  class CountsController < BaseController
    skip_before_action :require_app_access
    before_action :require_signed_in

    def show
      units = Aim::Users.shared_budget_units(current_user_employee_id, staff: helpers.aim_queue_access?)
      counts = { my_queue: my_queue_count, shared_queues: Aim::Invoice.shared_for(units).count }
      counts[:queues] = Aim::Invoice.queue_counts if helpers.aim_queue_access?
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
