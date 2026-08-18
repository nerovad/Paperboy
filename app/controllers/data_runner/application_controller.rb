# frozen_string_literal: true

module DataRunner
  class ApplicationController < ::ApplicationController
    # Reorganizing the DSL catalog is a grant of its own, separate from
    # browsing and running what is in it. Listed here rather than on
    # DslsController so the gate sits beside the app's other one.
    GROUP_ACTIONS = %i[new_group create_group update_group rename_group destroy_group].freeze

    before_action :require_app_access
    before_action :require_group_management

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

    # Which individual DSLs a user sees is not an ACL question today — only
    # whether they may create groups and move DSLs between them. See ACL >
    # Application Features under Data Runner.
    def require_group_management
      return unless GROUP_ACTIONS.include?(action_name.to_sym)

      require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path)
    end
  end
end
