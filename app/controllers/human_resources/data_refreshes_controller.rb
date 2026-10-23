# frozen_string_literal: true

module HumanResources
  class DataRefreshesController < BaseController
    include DataRunner::DataRefreshable

    before_action -> { require_app_feature('human_resources', 'data_refresh', fallback: human_resources_root_path) }

    def status
      render_data_refresh_status
    end

    private

    def data_refresh_service = DataRefresh
    def data_refresh_app_label = 'Human Resources'
    def data_refresh_css_class = 'human-resources'
    def data_refresh_form_path = human_resources_data_refresh_path
    def data_refresh_progress_path(run) = human_resources_data_refresh_run_path(run)
    def data_refresh_status_path(run) = human_resources_data_refresh_run_status_path(run)
    def data_refresh_log_path(run) = human_resources_data_refresh_run_log_path(run)
    def data_refresh_restart_path(run_id:) = restart_human_resources_data_refresh_path(run_id: run_id)
    def data_refresh_cancel_path = human_resources_root_path
  end
end
