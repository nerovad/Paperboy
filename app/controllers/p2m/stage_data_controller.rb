# frozen_string_literal: true

module P2m
  class StageDataController < ApplicationController
    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :set_dates

    def show
      @report = PrintAndInsertingDone.report
      @staging_running = StageData.active_run.present?
    end

    def create
      validate_date_range!
      StageData.enqueue!(start_date: @start_date, end_date: @end_date, requested_by: current_user.email)
      redirect_to p2m_stage_data_path,
                  notice: 'OMS staging started.'
    rescue StageData::ActiveRun
      redirect_to p2m_stage_data_path, alert: 'OMS staging is already running.'
    rescue ArgumentError
      flash.now[:alert] = 'Start date must be on or before end date.'
      @report = PrintAndInsertingDone.report
      @staging_running = StageData.active_run.present?
      render :show, status: :unprocessable_content
    rescue StandardError => e
      flash.now[:alert] = "OMS staging failed: #{e.message}"
      @report = PrintAndInsertingDone.report
      @staging_running = StageData.active_run.present?
      render :show, status: :unprocessable_content
    end

    private

    def set_dates
      values = params.fetch(:stage_data, {}).permit(:start_date, :end_date)
      @start_date = parse_date(values[:start_date]) || Date.current
      @end_date = parse_date(values[:end_date]) || Date.current
    end

    def parse_date(value)
      Date.iso8601(value) if value.present?
    rescue Date::Error
      nil
    end

    def validate_date_range!
      raise ArgumentError if @start_date > @end_date
    end
  end
end
