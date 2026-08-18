# frozen_string_literal: true

module DataRunner
  class RunsController < ApplicationController
    before_action :require_login

    def show
      @group_run = GroupRun.find_by(run_id: params[:id])
      return redirect_to billing_data_refresh_run_log_path(@group_run) if billing_data_refresh?

      @output = TaskRunner.output!(params[:id])
    end

    private

    def billing_data_refresh?
      @group_run&.group_name == Billing::DataRefresh::GROUP_RUN_NAME
    end
  end
end
