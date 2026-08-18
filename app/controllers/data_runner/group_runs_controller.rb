# frozen_string_literal: true

module DataRunner
  class GroupRunsController < ApplicationController
    before_action :require_login
    before_action :set_run

    def show; end

    def status
      render partial: 'progress', locals: { run: @run.reload }
    end

    private

    def set_run
      @run = GroupRun.includes(:items).find(params[:id])
    end
  end
end
