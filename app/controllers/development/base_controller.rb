# frozen_string_literal: true

module Development
  class BaseController < ::ApplicationController
    before_action :require_app_access

    private

    def require_app_access
      return if current_user.present? && helpers.can_access_app?('development')

      redirect_to root_path, alert: 'You do not have access to Development.'
    end
  end
end
