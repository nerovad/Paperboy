# frozen_string_literal: true

module DataRunner
  class LogsController < ApplicationController
    before_action :require_login
    before_action :set_log, only: %i[show edit update destroy]

    def index
      @filters = search_params
      @filter_options = Log.filter_options
      @logs = Log.search(@filters).limit(250)
    end

    def show; end

    def new
      now = Time.current
      @log = Log.new(run_id: SecureRandom.uuid, status: 'succeeded', started_at: now,
                     completed_at: now, duration_ms: 0)
    end

    def edit; end

    def create
      @log = Log.new(log_params)
      return redirect_to(data_runner_log_path(@log), notice: 'Log created.') if @log.save

      render :new, status: :unprocessable_entity
    end

    def update
      return redirect_to(data_runner_log_path(@log), notice: 'Log updated.') if @log.update(log_params)

      render :edit, status: :unprocessable_entity
    end

    def destroy
      @log.destroy!
      redirect_to data_runner_logs_path, notice: 'Log deleted.', status: :see_other
    end

    private

    def set_log
      @log = Log.find(params[:id])
    end

    def log_params
      params.expect(data_runner_log: %i[run_id command script arguments selector status exit_status started_at
                                        completed_at duration_ms cwd host_name os_user process_id git_sha error_class
                                        error_message])
    end

    def search_params
      params.permit(:date, :command, :dsl, :status, :duration)
    end
  end
end
