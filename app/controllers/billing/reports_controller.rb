# frozen_string_literal: true

module Billing
  class ReportsController < BaseController
    before_action :require_system_admin

    def index
      @report_files = ReportFile.all
    end

    def show
      report_file = ReportFile.find(params[:filename])
      send_data report_file.path.binread,
                filename: report_file.filename,
                type: report_file.content_type,
                disposition: report_file.pdf? ? 'inline' : 'attachment'
    end
  end
end
