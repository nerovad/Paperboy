# frozen_string_literal: true

module Billing
  class DataRefreshesController < BaseController
    before_action -> { require_app_feature('billing', 'data_refresh', fallback: billing_root_path) }
    before_action :set_active_billing_period
    before_action :load_groups

    def show
      @output = TaskRunner.output!(params[:run_id]) if params[:run_id].present?
    end

    def update
      result = DataRefresh.run!(group_values)
      return redirect_to billing_data_refresh_path, notice: 'No Data Runner groups were selected.' unless result

      message = "Data refresh #{result.success ? 'completed successfully' : 'failed'}."
      destination = billing_data_refresh_path(run_id: result.id)
      redirect_to destination, result.success ? { notice: message } : { alert: message }
    rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
      Rails.logger.error("Billing data refresh failed: #{e.class}: #{e.message}")
      redirect_to billing_data_refresh_path, alert: 'The data refresh could not be started.'
    end

    private

    def load_groups
      @groups = DataRefresh.groups(end_date: @active_billing_period&.end_date)
    end

    def group_values
      params.require(:groups).permit(*DataRefresh::GROUPS.keys).to_h
    end
  end
end
