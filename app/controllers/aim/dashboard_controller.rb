# frozen_string_literal: true

module Aim
  class DashboardController < BaseController
    # #home is the app's front door and must stay open to anyone who holds the
    # app itself. The dashboard behind it is the pipeline for AIM Admins, and
    # their own work for anyone else with a queue (#131).
    before_action :require_queue, only: :index

    PIPELINE_COLUMNS = { 'Action Needed' => %w[needs_review needs_split], 'Ready for Approval' => %w[ready_for_approval],
                         'Exporting' => %w[approved exporting], 'Failed' => %w[failed] }.freeze

    def home; end

    # The pipeline at a glance (revamped for #131): what needs attention, the
    # queue cards, today's movement, the oldest waiting for approval, and each
    # agency group's share -- for the groups picked in Managing.
    def index
      return mine unless helpers.aim_queue_access?

      @dashboard_queues = Aim::Invoice::QUEUES
      reading_database('read the invoices for the dashboard', errors: StandardError,
                                                              empty: { review_reasons: {}, tiles: [], today: {}, oldest: [], stale: [], by_group: {} }) do
        invoices = helpers.aim_agency_groups.invoices(helpers.aim_managing_groups)
        stats = Aim::DashboardStats.new(invoices, groups: helpers.aim_agency_groups)
        @review_reasons = invoices.in_queue('needs_review').group(:review_reason).count
        @tiles = stats.pipeline_tiles(helpers)
        @today = stats.today
        @oldest = stats.oldest('ready_for_approval')
        @stale = stats.stale
        @by_group = helpers.aim_managing_group ? {} : stats.by_group(PIPELINE_COLUMNS)
      end
    end

    private

    def require_queue
      redirect_to aim_root_path, alert: 'Your dashboard comes with a queue of your own.' unless helpers.aim_has_queue?
    end

    # Someone's own work: their queue, what has waited, what waits on their
    # second approval or their typing.
    def mine
      reading_database('read your invoices', errors: StandardError, empty: { tiles: [], oldest: [] }) do
        stats = Aim::DashboardStats.new(Aim::Invoice.owned_by(current_user_employee_id), groups: helpers.aim_agency_groups)
        @tiles = stats.personal_tiles(helpers)
        @oldest = stats.oldest('ready_for_approval')
      end
      render :mine
    end
  end
end
