# frozen_string_literal: true

module DataRunner
  class ApplicationController < ::ApplicationController
    # Reorganizing the DSL catalog is a grant of its own, separate from
    # browsing and running what is in it. Listed here rather than on
    # DslsController so the gate sits beside the app's other one.
    GROUP_ACTIONS = %i[new_group create_group update_group rename_group destroy_group].freeze

    before_action :require_app_access
    before_action :require_dsl_access
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
      return unless user_signed_in?
      return if helpers.can_access_app?('data_runner') || Rails.env.test?

      redirect_to root_path, alert: 'You do not have access to Data Runner.'
    end

    # Every route that names a DSL names it in +params[:name]+ — the catalog is
    # `resources :dsls, param: :name`, so show, edit, update, destroy, run,
    # reference and the output routes all arrive here. Gating in one place
    # rather than in each controller's set_dsl means a controller added later
    # is covered before it is written.
    #
    # As everywhere else, the sidebar only hides: without this a DSL stays
    # reachable by typing its URL.
    def require_dsl_access
      slug = params[:name]
      return if slug.blank? || helpers.can_use_dsl?(slug)

      redirect_to data_runner_root_path, alert: 'You do not have access to that DSL.'
    end

    # Creating groups and moving DSLs between them is a grant of its own, over
    # and above being able to open the DSLs themselves. See ACL > Application
    # Features under Data Runner.
    def require_group_management
      return unless GROUP_ACTIONS.include?(action_name.to_sym)

      require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path)
    end
  end
end
