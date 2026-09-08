# frozen_string_literal: true

module P2m
  class ProductionsController < ApplicationController
    before_action -> { require_app_feature('p2m', 'stage_data', fallback: p2m_root_path) }

    def show
      @queues = ProductionFiles.new.call
    rescue SystemCallError => e
      flash.now[:alert] = "Production files could not be loaded: #{e.message}"
      @queues = []
      render :show, status: :unprocessable_content
    end

    def preview
      file = ProductionFiles.new.preview(**preview_parameters)
      send_file file, filename: file.basename.to_s,
                      type: Rack::Mime.mime_type(file.extname, 'application/octet-stream'),
                      disposition: 'inline'
    rescue ArgumentError, ActionController::ParameterMissing => e
      render plain: e.message, status: :unprocessable_content
    end

    private

    def preview_parameters
      params.require(%i[printer queue filename])
      params.permit(:printer, :queue, :filename).to_h.symbolize_keys
    end
  end
end
