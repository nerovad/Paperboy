# frozen_string_literal: true

module Aim
  # Fiscal's bulk export: tick invoices, download the file (Aim::FiscalExport),
  # and the ready ones become exported. Exported ones can be downloaded again
  # and stay as they are.
  class FiscalExportsController < BaseController
    before_action :require_fiscal

    def create
      records = Aim::FiscalRecord.includes(:invoice).where(id: Array(params[:record_ids]), status: %w[ready exported]).to_a
      return redirect_to(back_path, alert: 'Tick at least one invoice to export.') if records.empty?

      format = Aim::FiscalExport::FORMATS.key?(params[:export_format]) ? params[:export_format] : 'docushare'
      export = Aim::FiscalExport.new(records)
      body = export.render(format)
      Aim::FiscalRecord.transaction do
        records.select { |record| record.status == 'ready' }.each do |record|
          record.move_to!('exported', actor: current_user_email, note: "export (#{format})", exported_at: Time.current)
        end
      end
      send_data body, filename: export.filename(format), type: export.content_type(format), disposition: 'attachment'
    end

    private

    def back_path
      remembered = session[:aim_fiscal_page].to_s
      remembered.start_with?('/aim/fiscal') ? remembered : aim_fiscal_path(status: 'ready')
    end
  end
end
