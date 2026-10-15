# frozen_string_literal: true

module Aim
  # Fiscal > Reports (#131): every processed report, numbered, for the agency
  # groups picked in Managing. Download one again exactly as it was made (until
  # its file is purged, a year on), see its invoices, or regenerate it from
  # their values now as a new numbered report.
  class FiscalReportsController < BaseController
    before_action :require_fiscal
    before_action :set_report, only: %i[show download regenerate]

    def index
      groups = helpers.aim_managing_groups
      scope = Aim::FiscalReport.newest_first.includes(:agency_group)
      scope = scope.where(agency_group_id: groups.map(&:id)) unless groups.nil?
      @reports = scope.limit(500).to_a
    end

    def show
      @invoices = @report.invoices.order(:id).to_a
      @replaced_by = Aim::FiscalReport.where(replaces_report_id: @report.id).order(:id).to_a
    end

    def download
      return redirect_to(aim_fiscal_report_path(@report), alert: 'This report\'s file was purged a year after it was made.') if @report.purged?

      send_data @report.content, filename: @report.file_name, type: @report.content_type, disposition: 'attachment'
    end

    # A new numbered report of the same invoices, from their values now, laid
    # out as this one was (its template if still saved, else its group's
    # Default). Statuses are left as they are.
    def regenerate
      records = Aim::FiscalRecord.includes(:invoice).where(invoice_id: @report.report_invoices.select(:invoice_id)).to_a
      return redirect_to(aim_fiscal_report_path(@report), alert: 'None of its invoices are with Fiscal any more.') if records.empty?

      export = Aim::FiscalExport.new(records, group: @report.layout)
      report = Aim::FiscalReport.process!(export, layout: @report.layout, by: current_user_email, replaces: @report)
      redirect_to aim_fiscal_report_path(report, download: 1), notice: "Report #{report.number} made from #{@report.number}; it is downloading."
    end

    private

    # Only a report of the groups this person works; one in no group is AIM
    # Admins' alone.
    def set_report
      @report = Aim::FiscalReport.find_by(id: params[:id])
      groups = helpers.aim_fiscal_reach
      return if @report && (groups.nil? || groups.any? { |g| g.id == @report.agency_group_id })

      redirect_to aim_fiscal_reports_path, alert: 'That report is not one of your agency groups\'.'
    end
  end
end
