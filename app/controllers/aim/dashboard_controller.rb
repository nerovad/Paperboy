# frozen_string_literal: true

module Aim
  class DashboardController < BaseController
    # #home is the app's front door and must stay open to anyone who holds the
    # app itself; the working dashboard behind it is for AIM Admins and Staff.
    before_action :require_aim_admin, only: :index

    def home; end

    def index
      @dashboard_queues = Aim::Invoice::QUEUES
      reading_database('read the invoices for the dashboard', empty: { review_reasons: {} }, errors: StandardError) do
        invoices = helpers.aim_agency_groups.invoices(helpers.aim_managing_groups)
        @review_reasons = invoices.in_queue('needs_review').group(:review_reason).count
      end
    end
  end
end
