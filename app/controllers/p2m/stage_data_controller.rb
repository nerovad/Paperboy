# frozen_string_literal: true

module P2m
  class StageDataController < ApplicationController
    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :set_dates

    def show
      @report = nil
    end

    def create
      validate_date_range!
      @report = PrintAndInsertingDone.scan(start_date: @start_date, end_date: @end_date)
      render :show
    rescue ArgumentError
      render_invalid_date_range
    rescue StandardError => e
      render_search_error(e)
    end

    def details
      @oms_number = params.require(:oms_number)
      @associated_files = OmsAssociatedFiles.new.call(
        directory: params.require(:directory), oms_number: @oms_number
      )
      render partial: 'maildat_details'
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    private

    def render_invalid_date_range
      flash.now[:alert] = 'Start date must be on or before end date.'
      @report = nil
      render :show, status: :unprocessable_content
    end

    def render_search_error(error)
      flash.now[:alert] = "Mail.dat search failed: #{error.message}"
      @report = nil
      render :show, status: :unprocessable_content
    end

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
