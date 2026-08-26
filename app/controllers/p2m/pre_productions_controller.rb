# frozen_string_literal: true

module P2m
  class PreProductionsController < ApplicationController
    include DateRange

    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :set_dates

    def show
      validate_date_range!
    rescue ArgumentError
      render_invalid_date_range(:show)
    end

    private

    def date_range_param_key
      :pre_production
    end
  end
end
