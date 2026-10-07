# frozen_string_literal: true

module P2m
  class StageDataController < ApplicationController
    include InlineFileResponse

    include DateRange

    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :require_change_job,
                  only: %i[move_to_staging remove_from_staging move_to_shipping_station remove_from_shipping_station]
    before_action :set_dates

    def show
      @report = nil
    end

    def create
      validate_date_range!
      @report = PrintAndInsertingDone.scan(start_date: @start_date, end_date: @end_date,
                                           cancellation_token: params[:search_token])
      render :show
    rescue ArgumentError
      @report = nil
      render_invalid_date_range(:show)
    rescue StandardError => e
      render_search_error(e)
    end

    def details
      @oms_number = params.require(:oms_number)
      @associated_files = OmsAssociatedFiles.new.call(
        directory: params.require(:directory), oms_number: @oms_number
      )
      render partial: 'p2m/shared/maildat_details', locals: { production_stage: :post }
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    def print_tray_labels
      file = OmsAssociatedFiles.new.tray_labels(**staging_parameters)
      send_inline_file(file)
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    def preview
      file = OmsAssociatedFiles.new.preview(
        **staging_parameters, filename: params.require(:filename)
      )
      send_inline_file(file)
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    def move_to_staging
      ledger = OmsUploadLedger.new
      ledger.ensure_stageable!(oms_number: staging_parameters.fetch(:oms_number))
      analysis = validate_staging_source!
      checksums = {}
      count = OmsStaging.new.stage(**staging_parameters, checksums: checksums)
      ledger.staged!(oms_number: staging_parameters.fetch(:oms_number), actor: current_user.email,
                     analysis: analysis, checksums: checksums)
      render json: { message: "#{count} files copied to #{Paths::STAGING}." }
    rescue P2m::OmsUploadLedger::ChangedFiles,
           P2m::OmsUploadLedger::InvalidDataset,
           ActiveRecord::RecordInvalid, ArgumentError, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def remove_from_staging
      count = nil
      OmsUploadLedger.new.remove!(oms_number: staging_parameters.fetch(:oms_number), actor: current_user.email) do
        count = OmsStaging.new.remove(**staging_parameters)
      end
      render json: { message: "#{count} files removed from #{Paths::STAGING}." }
    rescue P2m::OmsUploadLedger::ImportStarted,
           ActiveRecord::RecordNotFound, ArgumentError, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def move_to_shipping_station
      count = OmsShippingStation.new.copy(**staging_parameters)
      render json: { message: "#{count} Mail.dat file copied to #{Paths::SHIPPING_STATION}." }
    rescue ArgumentError, RuntimeError => e
      render_shipping_error(e, :unprocessable_content)
    rescue StandardError => e
      Rails.logger.error("P2M shipping station failed for OMS #{params[:oms_number]}: #{e.full_message}")
      render_shipping_error(e, :internal_server_error)
    end

    def remove_from_shipping_station
      count = OmsShippingStation.new.remove(**staging_parameters)
      render json: { message: "#{count} Mail.dat file removed from #{Paths::SHIPPING_STATION}." }
    rescue ArgumentError, RuntimeError => e
      render_shipping_error(e, :unprocessable_content)
    rescue StandardError => e
      Rails.logger.error("P2M shipping station removal failed for OMS #{params[:oms_number]}: #{e.full_message}")
      render_shipping_error(e, :internal_server_error)
    end

    private

    def staging_parameters
      params.permit(:directory, :oms_number).to_h.symbolize_keys
    end

    def render_shipping_error(error, status)
      oms_number = params[:oms_number].presence || 'unknown'
      render json: { message: "OMS #{oms_number}: #{error.message}" }, status: status
    end

    def validate_staging_source!
      parameters = staging_parameters
      OmsAssociatedFiles.new.call(**parameters)
      source = OmsAssociatedFiles::ROOT.join(parameters.fetch(:directory))
      OmsUploadLedger.new(staging_path: source).validate!(oms_number: parameters.fetch(:oms_number))
    end

    def date_range_param_key = :stage_data
  end
end
