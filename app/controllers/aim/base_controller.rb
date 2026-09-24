# frozen_string_literal: true

module Aim
  # Base controller for the Automated Invoice Management app. Every AIM
  # controller inherits from this so the ACL gate below is applied
  # consistently.
  class BaseController < ApplicationController
    before_action :require_app_access
    before_action :load_aim_sidebar_counts

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so
    # this is the real gate: without it AIM would stay reachable by typing the
    # URL. Access is granted per group or org level under ACL > Applications;
    # system admins bypass it.
    #
    # The signed-in check matters: a global (all-org-nil) application grant
    # applies to everyone, so the grant alone would let a signed-out visitor
    # through.
    def require_app_access
      return if current_user.present? && helpers.can_access_app?('aim')

      redirect_to root_path, alert: 'You do not have access to Automated Invoice Management.'
    end

    # Who may reach the processing queues lives in Aim::AccessHelper, so the
    # command palette can ask it from apps where no AIM controller is running.
    def require_aim_admin
      return if helpers.aim_queue_access?

      redirect_to aim_root_path, alert: 'You do not have access to AIM processing queues.'
    end

    # One query: the sidebar and the dashboard count rows, which are the
    # truth. A database that cannot be reached must never take an AIM screen
    # down, so the counts go blank rather than raising.
    def load_aim_sidebar_counts
      @aim_queue_counts = Aim::Invoice.queue_counts
      @aim_my_queue_count = Aim::Invoice.owned_by(current_user_employee_id).in_queue('ready_for_approval').count if current_user_employee_id
    rescue StandardError => e
      Rails.logger.error "Failed to load AIM queue counts: #{e.message}"
      @aim_queue_counts = {}
    end

    def current_user_email
      session.dig(:user, 'email') || session.dig('user', 'email') || 'Unknown User'
    end

    def current_user_name
      user = session[:user] || session['user'] || {}
      [user['first_name'], user['last_name']].compact_blank.join(' ').presence
    end

    def current_user_employee_id
      user = session[:user] || session['user'] || {}
      user['employee_id'].presence&.to_i
    end

    def current_user_unit
      user = session[:user] || session['user'] || {}
      user['unit'].presence
    end
  end
end
