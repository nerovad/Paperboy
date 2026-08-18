# frozen_string_literal: true

module DataRunner
  class RunsController < ApplicationController
    before_action :require_login

    def show
      @output = TaskRunner.output!(params[:id])
      @group_run = GroupRun.find_by(run_id: params[:id])
    end
  end
end
