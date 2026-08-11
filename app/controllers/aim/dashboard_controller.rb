# frozen_string_literal: true

module Aim
  class DashboardController < BaseController
    # #home is the app's front door and must stay open to anyone who holds the
    # app itself; only the working dashboard behind it is a grant of its own.
    before_action only: :index do
      require_app_feature('aim', 'dashboard', fallback: aim_root_path)
    end

    def home; end

    def index
      @dashboard_queues = Aim::InvoiceDirectoryService::BACKEND_QUEUES
    end
  end
end
