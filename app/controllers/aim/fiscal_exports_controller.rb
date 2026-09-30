# frozen_string_literal: true

module Aim
  # Fiscal's report: tick invoices, download the CSV (Aim::FiscalExport), and
  # those in the Report Queue become exported. Exported ones can be downloaded
  # again and stay as they are.
  class FiscalExportsController < BaseController
    before_action :require_fiscal

    def create
      records = Aim::FiscalRecord.includes(:invoice).where(id: Array(params[:record_ids]), status: %w[ready exported]).to_a
      return redirect_to(back_path, alert: 'Tick at least one invoice for the report.') if records.empty?

      export = Aim::FiscalExport.new(records)
      body = export.to_csv
      Aim::FiscalRecord.transaction do
        records.select { |record| record.status == 'ready' }.each do |record|
          record.move_to!('exported', actor: current_user_email, note: 'in the report', exported_at: Time.current)
        end
      end
      send_data body, filename: export.filename, type: 'text/csv', disposition: 'attachment'
    end

    private

    def back_path = remembered_return(:aim_fiscal_page, '/aim/fiscal') { aim_fiscal_path(status: 'ready') }
  end
end
