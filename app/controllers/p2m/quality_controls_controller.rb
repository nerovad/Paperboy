# frozen_string_literal: true

module P2m
  class QualityControlsController < ApplicationController
    include DateRange

    before_action -> { require_app_feature('p2m', 'quality_control', fallback: p2m_root_path) }
    before_action :set_dates

    def show
      validate_date_range!
      @oms_rows = P2m::QualityControl.oms_rows(start_date: @start_date, end_date: @end_date)
    rescue ArgumentError
      @oms_rows = []
      render_invalid_date_range(:show)
    end

    def details
      validate_date_range!
      @oms_number = params.require(:oms_number)
      @details = P2m::QualityControl.details(oms_number: @oms_number)
      render partial: 'details'
    rescue ArgumentError
      render plain: 'Invalid date range.', status: :unprocessable_content
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("P2M QC detail query failed: #{e.message}")
      render plain: 'Quality control detail query failed.', status: :internal_server_error
    end

    private

    def date_range_param_key = :quality_control
  end
end
