# frozen_string_literal: true

module Aim
  # A Fiscal report's layout (#131): which columns, in what order, under what
  # headers, and the file format. An agency group's own is its Default; its
  # saved templates (Aim::ReportTemplate) are others. Both keep it in
  # export_columns and export_format, and Aim::FiscalExport reads either.
  module ReportLayout
    extend ActiveSupport::Concern

    EXPORT_FORMATS = { 'csv' => 'Comma-separated, UTF-8', 'tab' => 'Tab-separated, UTF-16' }.freeze

    included do
      validates :export_format, inclusion: { in: EXPORT_FORMATS.keys }
      validate :fiscal_settings_known
    end

    # The report's layout, kept as JSON in export_columns:
    #   {"columns": ["Invoice Number", ...], "headers": {"Invoice Number": "Inv #"}}
    # A bare list (the first form) still reads. Blank is AIM's report as is.
    def export_settings
      raw = JSON.parse(export_columns.presence || 'null')
      raw = { 'columns' => raw } if raw.is_a?(Array)
      raw.is_a?(Hash) ? raw : {}
    rescue JSON::ParserError
      {}
    end

    # The report's columns, in this layout's order.
    def export_column_list
      list = Array(export_settings['columns']).map(&:to_s).uniq & Aim::FiscalExport::COLUMNS
      list.any? ? list : Aim::FiscalExport::COLUMNS
    end

    def export_column_list=(names)
      store_export(columns: Array(names).map(&:to_s).uniq & Aim::FiscalExport::COLUMNS)
    end

    # Every column, this layout's first in its order, then the ones left out.
    def export_column_order = export_column_list | Aim::FiscalExport::COLUMNS

    # { column => the header this layout gives it }, renamed ones only.
    def export_headers
      headers = export_settings['headers']
      headers.is_a?(Hash) ? headers.slice(*Aim::FiscalExport::COLUMNS).transform_values { |v| v.to_s.squish }.compact_blank : {}
    end

    def export_headers=(names)
      renamed = names.to_h.transform_keys(&:to_s).transform_values { |v| v.to_s.squish }
                     .select { |column, header| Aim::FiscalExport::COLUMNS.include?(column) && header.present? && header != column }
      store_export(headers: renamed)
    end

    def export_header(column) = export_headers.fetch(column, column)

    private

    # Nothing stored when the report is AIM's own; no columns ticked is an error.
    def store_export(columns: nil, headers: nil)
      settings = export_settings
      columns ||= settings.key?('columns') ? Array(settings['columns']) : Aim::FiscalExport::COLUMNS
      headers ||= export_headers
      self.export_columns = if columns == Aim::FiscalExport::COLUMNS && headers.empty? then nil
                            else { 'columns' => columns, 'headers' => headers }.to_json
                            end
    end

    def fiscal_settings_known
      return if export_columns.blank?

      columns = export_settings['columns']
      errors.add(:base, 'Pick at least one column for the report') unless columns.is_a?(Array) && columns.intersect?(Aim::FiscalExport::COLUMNS)
    end
  end
end
