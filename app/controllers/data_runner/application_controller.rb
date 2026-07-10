# frozen_string_literal: true

module DataRunner
  class ApplicationController < ::ApplicationController
    helper_method :user_signed_in?

    def user_signed_in?
      current_user.present?
    end

    def require_login
      redirect_to data_runner_root_path, alert: "Please sign in to continue." unless user_signed_in?
    end
  end
end
