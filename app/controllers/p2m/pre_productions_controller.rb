# frozen_string_literal: true

module P2m
  class PreProductionsController < ApplicationController
    include DateRange

    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    before_action :set_dates

    def show
      validate_date_range!
      if params[:pre_production]
        @report = PrintAndInsertingDone.scan(start_date: @start_date, end_date: @end_date)
        @printer_queues = PrinterCatalog.new.call
      end
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

    def send_to_printer
      parameters = printer_parameters
      validate_printer_queue!(parameters.fetch(:printer), parameters.fetch(:queue))
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      count = PrinterQueue.new.copy(**parameters)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      render json: {
        message: "#{count} files copied to #{parameters.fetch(:printer)}/#{parameters.fetch(:queue)}.",
        elapsed_seconds: elapsed.round(4)
      }
    rescue ArgumentError, ActionController::ParameterMissing, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def remove_from_printer
      parameters = printer_parameters
      validate_printer_queue!(parameters.fetch(:printer), parameters.fetch(:queue))
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      count = PrinterQueue.new.remove(**parameters)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      render json: {
        message: "#{count} #{'file'.pluralize(count)} removed from " \
                 "#{parameters.fetch(:printer)}/#{parameters.fetch(:queue)}.",
        elapsed_seconds: elapsed.round(4)
      }
    rescue ArgumentError, ActionController::ParameterMissing, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    def destroy_oms
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = OmsDestroyer.new.call(**params.permit(:directory, :oms_number).to_h.symbolize_keys)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      render json: {
        message: "#{result.fetch(:archived)} files copied to Destroyed; " \
                 "#{result.fetch(:removed)} working copies removed.",
        elapsed_seconds: elapsed.round(4)
      }
    rescue ArgumentError, ActionController::ParameterMissing, RuntimeError => e
      render json: { message: e.message }, status: :unprocessable_content
    end

    private

    def date_range_param_key
      :pre_production
    end

    def printer_parameters
      permitted = params.permit(:directory, :oms_number, :printer, :queue, selected_files: [])
      values = permitted.to_h.symbolize_keys
      values[:filenames] = values.delete(:selected_files) if permitted.key?(:selected_files)
      validate_pdf_filenames!(values[:filenames]) if values.key?(:filenames)
      values
    end

    def validate_printer_queue!(printer, queue)
      queues = PrinterCatalog.new.call
      raise ArgumentError, 'invalid printer or queue' unless queues.fetch(printer, []).include?(queue)
    end

    def validate_pdf_filenames!(filenames)
      invalid = Array(filenames).reject { |name| File.extname(name).casecmp?('.pdf') }
      raise ArgumentError, "only PDF files may be sent to a printer: #{invalid.first}" if invalid.any?
    end
  end
end
