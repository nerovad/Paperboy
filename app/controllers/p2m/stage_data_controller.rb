# frozen_string_literal: true

module P2m
  class StageDataController < ApplicationController
    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :set_dates

    def show; end

    def create
      validate_date_range!
      redirect_to p2m_stage_data_path,
                  notice: 'Stage Data is a placeholder. No data was staged.'
    rescue ArgumentError
      flash.now[:alert] = 'Start date must be on or before end date.'
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
