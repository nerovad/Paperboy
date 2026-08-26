# frozen_string_literal: true

module P2m
  module DateRange
    extend ActiveSupport::Concern

    private

    def set_dates
      values = params.fetch(date_range_param_key, {}).permit(:start_date, :end_date)
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

    def render_invalid_date_range(template)
      flash.now[:alert] = 'Start date must be on or before end date.'
      render template, status: :unprocessable_content
    end
  end
end
