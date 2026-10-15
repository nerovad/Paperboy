# frozen_string_literal: true

module Aim
  # An invoice in a saved Fiscal report (#131).
  class FiscalReportInvoice < Record
    belongs_to :fiscal_report, class_name: 'Aim::FiscalReport'
    belongs_to :invoice, class_name: 'Aim::Invoice'

    validates :invoice_id, uniqueness: { scope: :fiscal_report_id }
  end
end
