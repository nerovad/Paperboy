# frozen_string_literal: true

module DataRunner
  class RunsController < ApplicationController
    before_action :require_login

    def show
      @output = TaskRunner.output!(params[:id])
    end
  end
end
