# frozen_string_literal: true

module Billing
  class DataRefreshesController < BaseController
    before_action -> { require_app_feature('billing', 'data_refresh', fallback: billing_root_path) }
    before_action :set_active_billing_period, only: %i[show update]
    before_action :load_groups, only: %i[show update]
    before_action :set_run, only: %i[progress status log]

    def show; end

    def update
      run = DataRefresh.run!(group_values, requested_by: current_user.email)
      return redirect_to billing_data_refresh_path, notice: 'No Data Runner groups were selected.' unless run

      redirect_to billing_data_refresh_run_path(run), notice: "Data refresh started for #{run.total_count} DSLs."
    rescue DataRunner::GroupRefresh::ActiveRun
      run = DataRunner::GroupRun.active.find_by!(group_name: DataRefresh::GROUP_RUN_NAME)
      redirect_to billing_data_refresh_run_path(run), alert: 'A Billing data refresh is already running.'
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
      redirect_to billing_data_refresh_run_path(run), notice: "Data refresh restarted for #{run.total_count} DSLs."
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing, KeyError => e
      Rails.logger.error("Billing data refresh restart failed: #{e.class}: #{e.message}")
      redirect_to billing_data_refresh_path, alert: 'The data refresh could not be restarted.'
    end

    def progress; end

    def status
      render partial: 'shared/progress_tracker', locals: progress_tracker_locals(@run.reload)
    end

    def log
      @output = TaskRunner.output!(@run.run_id)
    end

    private

    def load_groups
      @groups = DataRefresh.groups(end_date: @active_billing_period&.end_date)
    end

    def group_values
      params.require(:groups).permit(*DataRefresh::GROUPS.keys).to_h
    end

    def set_run
      @run = DataRunner::GroupRun.includes(:items).find_by!(id: params[:run_id],
                                                            group_name: DataRefresh::GROUP_RUN_NAME)
    end

    def progress_tracker_locals(run)
      {
        run: run,
        restart_path: restart_billing_data_refresh_path(run_id: run.id),
        interrupted_restart_path: restart_billing_data_refresh_path(run_id: run.id),
        restart_confirmation: 'Restart the Billing data refresh?',
        log_path: billing_data_refresh_run_log_path(run),
        return_path: billing_data_refresh_path,
        return_label: 'Return to Billing'
      }
    end
    helper_method :progress_tracker_locals
  end
end
