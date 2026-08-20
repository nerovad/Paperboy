# frozen_string_literal: true

module Billing
  class DataRefreshesController < BaseController
    include DataRunner::DataRefreshable

    before_action -> { require_app_feature('billing', 'data_refresh', fallback: billing_root_path) }
    before_action :set_active_billing_period, only: %i[show update]

    def status
      render_data_refresh_status
    end

    private

    def data_refresh_service = DataRefresh
    def data_refresh_app_label = 'Billing'
    def data_refresh_css_class = 'billing'
    def data_refresh_form_path = billing_data_refresh_path
    def data_refresh_progress_path(run) = billing_data_refresh_run_path(run)
    def data_refresh_status_path(run) = billing_data_refresh_run_status_path(run)
    def data_refresh_log_path(run) = billing_data_refresh_run_log_path(run)
    def data_refresh_restart_path(run_id:) = restart_billing_data_refresh_path(run_id: run_id)
    def data_refresh_cancel_path = billing_root_path
    def data_refresh_end_date = @active_billing_period&.end_date
  end
end
