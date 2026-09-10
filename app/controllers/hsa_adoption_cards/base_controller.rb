# frozen_string_literal: true

module HsaAdoptionCards
  # Base controller for the HSA Adoption Card Search app. Every controller in
  # the app inherits from this so the ACL gate below is applied consistently.
  class BaseController < ApplicationController
    before_action :require_app_access

    private

    # The sidebar app switcher only *hides* apps the user cannot reach, so
    # this is the real gate: without it the app would stay reachable by
    # typing the URL. Access is granted per group or org level under
    # ACL > Applications; system admins bypass it.
    #
    # The signed-in check matters: a global (all-org-nil) application grant
    # applies to everyone, so the grant alone would let a signed-out visitor
    # through.
    def require_app_access
      return if current_user.present? && helpers.can_access_app?('hsa_adoption_cards')

      redirect_to root_path, alert: 'You do not have access to HSA Adoption Card Search.'
    end

    # Search and Browse are each a grant of their own under ACL > Application
    # Features, so a group can be given one without the other.
    def require_feature(feature)
      require_app_feature('hsa_adoption_cards', feature, fallback: hsa_adoption_cards_root_path)
    end

    # What the search log records as the person who searched. The SQL login
    # is Paperboy's own account, so this is the only place the real user's
    # identity reaches the audit trail.
    def app_user
      current_user.email
    end

    # The page and the procedures agree on a JSON shape: { user, rows } on
    # success, { error, detail } when refused or broken. Errors go out as 200
    # so the page distinguishes "the procedure said no" from "the server is
    # down" — exactly as the PowerShell helper did.
    def render_rows
      rows = yield
      render json: { user: current_user.email, rows: rows }
    rescue HsaAdoptionCards::Error => e
      Rails.logger.warn "HSA Adoption Card Search refused/failed for #{app_user}: #{e.message}"
      render json: { error: e.message, detail: e.detail }
    end

    # The page posts a JSON body. Only scalar values are taken, so a nested
    # object can never reach a procedure parameter.
    def json_params
      body = request.body.read
      parsed = body.present? ? JSON.parse(body) : {}
      parsed.select { |_key, value| value.nil? || value.is_a?(String) || value.is_a?(Numeric) || [true, false].include?(value) }
    rescue JSON::ParserError
      {}
    end
  end
end
