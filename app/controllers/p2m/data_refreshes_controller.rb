# frozen_string_literal: true

module P2m
  class DataRefreshesController < ApplicationController
    include DataRunner::DataRefreshable

    before_action -> { require_app_feature('p2m', 'data_refresh', fallback: p2m_root_path) }

    def status
      render_data_refresh_status
    end

    private

    def data_refresh_service = DataRefresh
    def data_refresh_app_label = 'Print 2 Mail'
    def data_refresh_css_class = 'p2m'
    def data_refresh_form_path = p2m_data_refresh_path
    def data_refresh_progress_path(run) = p2m_data_refresh_run_path(run)
    def data_refresh_status_path(run) = p2m_data_refresh_run_status_path(run)
    def data_refresh_log_path(run) = p2m_data_refresh_run_log_path(run)
    def data_refresh_restart_path(run_id:) = restart_p2m_data_refresh_path(run_id: run_id)
    def data_refresh_cancel_path = p2m_root_path
    def data_refresh_unit_name = 'upload'
    def data_refresh_preview_entries = data_refresh_service.preview_entries

    def data_refresh_selected_entries
      params.fetch(:selected_oms_numbers, [])
    end
  end
end
