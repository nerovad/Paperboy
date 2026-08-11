# frozen_string_literal: true

module Billing
  class ReportsController < BaseController
    SORT_COLUMNS = %w[file modified size].freeze
    SORT_DIRECTIONS = %w[asc desc].freeze

    before_action -> { require_app_feature('billing', 'view_reports', fallback: billing_root_path) }
    before_action :set_active_billing_period, only: :index
    helper_method :report_sort_direction, :report_sort_indicator

    def index
      @sort = SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : 'file'
      @direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : 'asc'
      @report_files = sort_report_files(ReportFile.all)
    end

    def show
      report_file = ReportFile.find(params[:filename])
      return render_xlsx_preview(report_file) if params[:preview] == 'true' && !report_file.pdf?

      send_data report_file.path.binread,
                filename: report_file.filename,
                type: report_file.content_type,
                disposition: report_file.pdf? ? 'inline' : 'attachment'
    end

    private

    def render_xlsx_preview(report_file)
      preview = WorkflowOutputPresenter.new(report_file.path)
      render partial: 'billing/reports/xlsx_preview',
             locals: { preview: preview }
    end

    def sort_report_files(report_files)
      sorted = report_files.sort_by do |report_file|
        case @sort
        when 'size' then report_file.size
        when 'modified' then report_file.modified_at
        else report_file.filename.downcase
        end
      end
      @direction == 'desc' ? sorted.reverse : sorted
    end

    def report_sort_direction(column)
      @sort == column && @direction == 'asc' ? 'desc' : 'asc'
    end

    def report_sort_indicator(column)
      return unless @sort == column

      @direction == 'asc' ? '▲' : '▼'
    end
  end
end
