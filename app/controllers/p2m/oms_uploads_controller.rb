# frozen_string_literal: true

module P2m
  class OmsUploadsController < ApplicationController
    include Pagy::Method

    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :set_dates

    def index
      validate_date_range!
      scope = OmsUpload.includes(:files, :findings)
                       .where(mailer_date: @start_date..@end_date)
                       .newest_first
      @pagy, @uploads = pagy(:offset, scope)
    rescue ArgumentError
      flash.now[:alert] = 'Start date must be on or before end date.'
      @uploads = OmsUpload.none
      render :index, status: :unprocessable_content
    end

    private

    def set_dates
      values = params.fetch(:oms_uploads, {}).permit(:start_date, :end_date)
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
