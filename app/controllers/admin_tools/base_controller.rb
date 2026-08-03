# frozen_string_literal: true

module AdminTools
  # Base controller for the Admin Tools app. Every Admin Tools controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    before_action :require_app_access

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so
    # this is the real gate: without it Admin Tools would stay reachable by
    # typing the URL. Access comes either from holding any one of the admin
    # tool grants (ACL, Manage Forms, Emulate, …) or from an ACL > Applications
    # grant for 'admin_tools'; system admins bypass it. Each tool still
    # enforces its own grant, so reaching this landing page never implies
    # being able to open a particular tool.
    #
    # The signed-in check matters: a global (all-org-nil) application grant
    # applies to everyone, so the grant alone would let a signed-out visitor
    # through.
    def require_app_access
      return if current_user.present? && helpers.can_access_app?('admin_tools')

      redirect_to root_path, alert: 'You do not have access to Admin Tools.'
    end
  end
end
