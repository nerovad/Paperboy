# frozen_string_literal: true

module Aim
  # Fiscal's report: tick invoices, download the CSV (Aim::FiscalExport), and
  # those in the Report Queue become exported. Exported ones can be downloaded
  # again and stay as they are.
  #
  # The report is laid out as one agency group says (#131): the group picked
  # in Managing, or the one whose Fiscal works every invoice ticked.
  class FiscalExportsController < BaseController
    before_action :require_fiscal

    def create
      invoices = helpers.aim_agency_groups.invoices(helpers.aim_fiscal_reach)
      records = Aim::FiscalRecord.includes(:invoice).served_by(invoices)
                                 .where(id: Array(params[:record_ids]), status: %w[ready exported]).to_a
      return redirect_to(back_path, alert: 'Tick at least one invoice for the report.') if records.empty?

      group = report_group(records)
      if group == :mixed
        return redirect_to(back_path, alert: 'Those invoices belong to agency groups with different reports. ' \
                                             'Pick one group under Managing, then download.')
      end

      export = Aim::FiscalExport.new(records, group: group)
      body = export.body
      Aim::FiscalRecord.transaction do
        records.select { |record| record.status == 'ready' }.each do |record|
          record.move_to!('exported', actor: current_user_email, note: 'in the report', exported_at: Time.current)
        end
      end
      send_data body, filename: export.filename, type: export.content_type, disposition: 'attachment'
    end

    private

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
