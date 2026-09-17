# frozen_string_literal: true

module Billing
  class CustomerLookupsController < BaseController
    include P2m::DateRange

    before_action -> { require_app_feature('billing', 'customer_lookup', fallback: billing_root_path) }
    before_action :set_dates

    def show
      @unit = nil
      @rows = nil
    end

    def create
      validate_date_range!
      @unit = find_unit
      @rows = @unit && CustomerLookup.new.call(
        start_date: @start_date, end_date: @end_date, unit: @unit
      )
      render :show
    rescue ArgumentError
      @unit = nil
      @rows = nil
      render_invalid_date_range(:show)
    rescue StandardError => e
      Rails.logger.error("Billing customer lookup failed: #{e.class}: #{e.message}")
      @unit = nil
      @rows = nil
      flash.now[:alert] = 'The customer lookup could not be completed.'
      render :show, status: :unprocessable_content
    end

    private

    def date_range_param_key = :customer_lookup

    def find_unit
      query = params.dig(:customer_lookup, :budget_unit).to_s.strip
      return if query.blank?

      Coa::Unit.where(unit_id: query).order(:agency_id, :division_id, :department_id).first
    end
  end
end
