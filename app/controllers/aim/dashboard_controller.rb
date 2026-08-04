# frozen_string_literal: true

module Aim
  class DashboardController < BaseController
    def index
      @dashboard_queues = Aim::InvoiceDirectoryService::BACKEND_QUEUES
    end
  end
end
