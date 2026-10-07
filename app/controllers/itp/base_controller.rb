# frozen_string_literal: true

module Itp
  # Base controller for the IT Portal app. Every IT Portal controller should
  # inherit from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    before_action :require_app_access

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so
    # this is the real gate: without it IT Portal would stay reachable by
    # typing the URL. Access is granted per group or org level under
    # ACL > Applications; system admins bypass it.
    #
    # The signed-in check matters: a global (all-org-nil) application grant
    # applies to everyone, so the grant alone would let a signed-out visitor
    # through.
    def require_app_access
      return if current_user.present? && helpers.can_access_app?('itp')

      redirect_to root_path, alert: 'You do not have access to IT Portal.'
    end
  end
end
