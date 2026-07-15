# frozen_string_literal: true

module DataRunner
  class ApplicationController < ::ApplicationController
    before_action :require_app_access

    helper_method :user_signed_in?

    def user_signed_in?
      current_user.present?
    end

    def require_login
      redirect_to data_runner_root_path, alert: 'Please sign in to continue.' unless user_signed_in?
    end

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so this
    # is the real gate: without it Data Runner stays reachable by typing the
    # URL. Access is granted per group or org level under ACL > Applications;
    # system admins bypass it.
    #
    # The signed-in check is part of the gate rather than left to
    # +require_login+: a global (all-org-nil) application grant applies to
    # everyone, so the grant alone would otherwise let a signed-out visitor
    # through on the actions that skip login.
    def require_app_access
      return if user_signed_in? && helpers.can_access_app?('data_runner')

      redirect_to root_path, alert: 'You do not have access to Data Runner.'
    end
  end
end
