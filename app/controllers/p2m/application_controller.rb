# frozen_string_literal: true

module P2m
  # Base controller for the Print 2 Mail app. Every Print 2 Mail controller should
  # inherit from this so the ACL gate below is applied consistently.
  class ApplicationController < ::ApplicationController
    include ApplicationAccessGate

    gate_application 'p2m', label: 'Print 2 Mail'

    private

    # Send, destroy, shipping, and staging answer fetch(), which reads a JSON
    # message. A redirect would be followed as the next document.
    def require_change_job
      return if helpers.can_use_app_feature?('p2m', 'change_job')

      render json: { message: 'Access denied.' }, status: :forbidden
    end
  end
end
