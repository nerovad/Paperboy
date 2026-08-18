# frozen_string_literal: true

module Billing
  class DataRefreshesController < BaseController
    before_action -> { require_app_feature('billing', 'data_refresh', fallback: billing_root_path) }
    before_action :set_active_billing_period
    before_action :load_groups

    def show; end

    def update
      run = DataRefresh.run!(group_values, requested_by: current_user.email)
      return redirect_to billing_data_refresh_path, notice: 'No Data Runner groups were selected.' unless run

      redirect_to data_runner_group_run_path(run), notice: "Data refresh started for #{run.total_count} DSLs."
    rescue DataRunner::GroupRefresh::ActiveRun
      run = DataRunner::GroupRun.active.find_by!(group_name: DataRefresh::GROUP_RUN_NAME)
      redirect_to data_runner_group_run_path(run), alert: 'A Billing data refresh is already running.'
    rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
      Rails.logger.error("Billing data refresh failed: #{e.class}: #{e.message}")
      redirect_to billing_data_refresh_path, alert: 'The data refresh could not be started.'
    end

    def restart
      previous_run = DataRunner::GroupRun.find_by!(id: params.require(:run_id),
                                                   group_name: DataRefresh::GROUP_RUN_NAME)
      entries = previous_run.items.order(:position).map { |item| DslCatalog.find!(item.dsl_slug) }
      run = DataRunner::GroupRefresh.restart!(group: DataRefresh::GROUP_RUN_NAME, entries: entries,
                                              requested_by: current_user.email)
      redirect_to data_runner_group_run_path(run), notice: "Data refresh restarted for #{run.total_count} DSLs."
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing, KeyError => e
      Rails.logger.error("Billing data refresh restart failed: #{e.class}: #{e.message}")
      redirect_to billing_data_refresh_path, alert: 'The data refresh could not be restarted.'
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
