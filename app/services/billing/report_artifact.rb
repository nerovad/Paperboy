# frozen_string_literal: true

module Billing
  ReportArtifact = Data.define(:name, :pdf_name, :pdf_data, :xlsx_name, :xlsx_data)
end
