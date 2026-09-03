# frozen_string_literal: true

module DataRunner
  class InboxDslsController < ApplicationController
    before_action :require_login
    before_action :require_dsl_management

    def create
      result = InboxDslCreator.new.create!
      count = result.created_slugs.size
      message = count.zero? ? 'No new inbox files were found.' : "Created #{count} #{'DSL'.pluralize(count)}."
      redirect_to data_runner_root_path, notice: message
    rescue DslCreator::InvalidDsl => e
      redirect_to data_runner_root_path, alert: "Inbox discovery failed: #{e.message}"
    end

    private

    def require_dsl_management
      require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path)
    end
  end
end
