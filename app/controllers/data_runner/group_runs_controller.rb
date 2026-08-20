# frozen_string_literal: true

module DataRunner
  class GroupRunsController < ApplicationController
    before_action :require_login
    before_action :set_run

    def show; end

    def status
      render partial: 'shared/progress_tracker', locals: progress_tracker_locals(@run.reload)
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
        interrupted_restart_path: data_runner_refresh_dsl_group_path(run.group_name, restart: 1),
        restart_confirmation: "Restart the #{run.group_name.humanize} refresh?",
        log_path: data_runner_run_path(run.run_id),
        return_path: data_runner_root_path(group: run.group_name),
        return_label: 'Return to group'
      }
    end
    helper_method :progress_tracker_locals
  end
end
