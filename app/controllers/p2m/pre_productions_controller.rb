# frozen_string_literal: true

module P2m
  class PreProductionsController < ApplicationController
    include DateRange

    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :set_dates

    def show
      validate_date_range!
      @report = PrintAndInsertingDone.scan(start_date: @start_date, end_date: @end_date) if params[:pre_production]
    rescue ArgumentError
      @report = nil
      render_invalid_date_range(:show)
    rescue StandardError => e
      flash.now[:alert] = "Mail.dat search failed: #{e.message}"
      @report = nil
      render :show, status: :unprocessable_content
    end

    def details
      @oms_number = params.require(:oms_number)
      @associated_files = OmsAssociatedFiles.new.call(
        directory: params.require(:directory), oms_number: @oms_number
      )
      @printer_queues = PrinterCatalog.new.call
      render partial: 'p2m/shared/maildat_details', locals: { production_stage: :pre }
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    private

    def date_range_param_key
      :pre_production
    end
  end
end
