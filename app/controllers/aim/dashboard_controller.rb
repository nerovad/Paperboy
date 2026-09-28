# frozen_string_literal: true

module Aim
  class DashboardController < BaseController
    # #home is the app's front door and must stay open to anyone who holds the
    # app itself; the working dashboard behind it is for AIM Admins and Staff.
    before_action :require_aim_admin, only: :index

    def home; end

    def index
      @dashboard_queues = Aim::Invoice::QUEUES
      @review_reasons = Aim::Invoice.in_queue('needs_review').group(:review_reason).count
    rescue StandardError => e
      Rails.logger.error "AIM dashboard could not read the invoices: #{e.message}"
      @review_reasons = {}
    end
  end
end
