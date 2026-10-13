# frozen_string_literal: true

module Aim
  # Fiscal's report (#131): tick invoices, preview the report, then either
  # download a draft (nothing saved, nothing moved) or process it -- saved,
  # numbered (Aim::FiscalReport), every invoice's history naming it, and the
  # Report Queue's moved to Exported. Processing lands on the saved report,
  # which downloads.
  #
  # The report is laid out as one agency group says: the template picked on
  # the page, the group picked in Managing, or the one whose Fiscal works
  # every invoice ticked.
  class FiscalExportsController < BaseController
    before_action :require_fiscal
    before_action :prepare

    ACTIONS = %w[draft process].freeze

    # The report as it will come out, in a dialog with the two downloads.
    def preview
      render 'aim/fiscal/report_preview', layout: false
    end

    def create
      return redirect_to(back_path, alert: @problem) if @problem
      return redirect_to(back_path, alert: 'Unknown action.') unless ACTIONS.include?(params[:report_action])

      return send_data(@export.body, filename: @export.filename, type: @export.content_type, disposition: 'attachment') if params[:report_action] == 'draft'

      report = Aim::FiscalReport.process!(@export, layout: @layout, by: current_user_email)
      redirect_to aim_fiscal_report_path(report, download: 1), notice: "Report #{report.number} saved; it is downloading."
    end

    private

    # @records, @layout and @export from the page's ticks and template, or
    # @problem saying why there is no report.
    def prepare
      invoices = helpers.aim_agency_groups.invoices(helpers.aim_fiscal_reach)
      @records = Aim::FiscalRecord.includes(:invoice).served_by(invoices)
                                  .where(id: Array(params[:record_ids]), status: %w[ready exported]).to_a
      @layout = picked_layout || report_group(@records)
      @problem = if @records.empty? then 'Tick at least one invoice for the report.'
                 elsif @layout == :mixed
                   'Those invoices belong to agency groups with different reports. Pick a template, or one group under Managing.'
                 end
      @export = Aim::FiscalExport.new(@records, group: @layout) unless @problem
    end

    # The layout picked on the page: a group's Default ("g<id>") or one of its
    # templates ("t<id>"), from the groups this person works; nil for none.
    def picked_layout
      kind, id = params[:report_template].to_s.match(/\A([gt])(\d+)\z/)&.captures
      return if kind.nil?

      groups = helpers.aim_fiscal_reach
      layout = kind == 'g' ? Aim::AgencyGroup.find_by(id: id) : Aim::ReportTemplate.find_by(id: id)
      owner = kind == 'g' ? layout : layout&.agency_group
      layout if owner && (groups.nil? || groups.any? { |g| g.id == owner.id })
    end

    # The group whose report this is: the one picked in Managing, or of the
    # invoices' groups the one whose Fiscal also processes all the others;
    # :mixed when there is none. nil (AIM's default report) for invoices
    # in no group.
    def report_group(records)
      return helpers.aim_managing_group if helpers.aim_managing_group

      groups = helpers.aim_agency_groups
      theirs = records.map { |record| groups.for_invoice(record.invoice) }.compact.uniq
      return if theirs.empty?

      theirs.find { |group| (theirs - groups.reach([group])).empty? } || :mixed
    end

    def back_path = remembered_return(:aim_fiscal_page, '/aim/fiscal') { aim_fiscal_path(status: 'ready') }
  end
end
