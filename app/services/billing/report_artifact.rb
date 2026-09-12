# frozen_string_literal: true

module Billing
  class ReportArtifact
    attr_reader :name, :pdf_name, :pdf_data, :overlay_pdf_name, :overlay_pdf_data,
                :xlsx_name, :xlsx_data

    def initialize(name:, pdf_name:, pdf_data:, xlsx_name:, xlsx_data:,
                   overlay_pdf_name: nil, overlay_pdf_data: nil)
      @name = name
      @pdf_name = pdf_name
      @pdf_data = pdf_data
      @overlay_pdf_name = overlay_pdf_name
      @overlay_pdf_data = overlay_pdf_data
      @xlsx_name = xlsx_name
      @xlsx_data = xlsx_data
    end
  end
end
