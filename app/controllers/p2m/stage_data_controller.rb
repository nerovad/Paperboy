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

    def print_tray_labels
      file = OmsAssociatedFiles.new.tray_labels(**staging_parameters)
      send_file file, filename: file.basename.to_s, type: 'application/pdf', disposition: 'inline'
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    def move_to_staging
      ledger = OmsUploadLedger.new
      ledger.ensure_stageable!(oms_number: staging_parameters.fetch(:oms_number))
      count = OmsStaging.new.stage(**staging_parameters)
      ledger.staged!(oms_number: staging_parameters.fetch(:oms_number), actor: current_user.email)
      render json: { message: "#{count} files copied to 00_SentToUSPS." }
    rescue P2m::OmsUploadLedger::ChangedFiles,
           ActiveRecord::RecordInvalid, ArgumentError, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def remove_from_staging
      count = nil
      OmsUploadLedger.new.remove!(oms_number: staging_parameters.fetch(:oms_number), actor: current_user.email) do
        count = OmsStaging.new.remove(**staging_parameters)
      end
      render json: { message: "#{count} files removed from 00_SentToUSPS." }
    rescue P2m::OmsUploadLedger::ImportStarted,
           ActiveRecord::RecordNotFound, ArgumentError, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def move_to_shipping_station
      count = OmsShippingStation.new.copy(**staging_parameters)
      render json: { message: "#{count} Mail.dat file copied to 00_ShippingStation." }
    rescue ArgumentError, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def remove_from_shipping_station
      count = OmsShippingStation.new.remove(**staging_parameters)
      render json: { message: "#{count} Mail.dat file removed from 00_ShippingStation." }
    rescue ArgumentError, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    private

    def staging_parameters
      params.permit(:directory, :oms_number).to_h.symbolize_keys
    end

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
