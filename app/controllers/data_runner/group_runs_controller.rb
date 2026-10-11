# frozen_string_literal: true

module DataRunner
  class GroupRunsController < ApplicationController
    before_action :require_login
    before_action :set_run
    before_action -> { require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path) },
                  only: :cancel

    def show; end

    def status
      render partial: 'shared/progress_tracker', locals: progress_tracker_locals(@run.reload)
    end

    def cancel
      group_name = @run.group_name
      if GroupRefresh.cancel!(@run)
        redirect_to data_runner_root_path(group: group_name),
                    notice: "#{group_name.humanize} refresh canceled."
      else
        redirect_to data_runner_group_run_path(@run),
                    alert: "#{group_name.humanize} refresh is no longer running."
      end
    end

    private

    def set_run
      @run = GroupRun.includes(:items).find(params[:id])
      if @run.group_name == Billing::DataRefresh::GROUP_RUN_NAME
        redirect_to billing_data_refresh_run_path(@run)
      elsif @run.group_name == P2m::DataRefresh::GROUP_RUN_NAME
        redirect_to p2m_data_refresh_run_path(@run)
      end
    end

    def progress_tracker_locals(run)
      {
        run: run,
        restart_path: data_runner_refresh_dsl_group_path(run.group_name),
        active_action_path: cancel_data_runner_group_run_path(run),
        active_action_label: 'Cancel refresh',
        active_action_variant: 'deny',
        active_action_confirmation: 'Cancel this refresh? The running refresh will stop and its progress will be cleared.',
        restart_confirmation: "Restart the #{run.group_name.humanize} refresh?",
        log_path: data_runner_run_path(run.run_id),
        return_path: data_runner_root_path(group: run.group_name),
        return_label: 'Return to group'
      }
    end
    helper_method :progress_tracker_locals
  end
end
