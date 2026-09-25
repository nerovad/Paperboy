# frozen_string_literal: true

module P2m
  class ProductionsController < ApplicationController
    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }
    after_action :cleanup_preview

    def show
      @queues = ProductionFiles.new.call
    rescue SystemCallError => e
      flash.now[:alert] = "Production files could not be loaded: #{e.message}"
      @queues = []
      render :show, status: :unprocessable_content
    end

    def preview
      @production_files = ProductionFiles.new
      file = @production_files.preview(**preview_parameters)
      @preview_file = file
      send_data File.binread(file),
                filename: file.basename.to_s,
                type: Rack::Mime.mime_type(file.extname, 'application/octet-stream'),
                disposition: 'inline'
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    def cleanup_preview
      return if @production_files.nil? || !@production_files.respond_to?(:cleanup_preview)

      @production_files.cleanup_preview(@preview_file)
    end

    private

    def preview_parameters
      params.require(%i[printer queue filename])
      params.permit(:printer, :queue, :filename).to_h.symbolize_keys
    end
  end
end
