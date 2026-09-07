# frozen_string_literal: true

# app/services/forms/audit_export/table.rb

require 'csv'

module Forms
  class AuditExport
    # One source's worth of export: the rows, the columns they sit under, and
    # the name they carry into the ZIP.
    #
    # Built even when empty, so a caller can say "no status changes in that
    # window" rather than silently dropping a source somebody asked for.
    Table = Struct.new(:source, :label, :headers, :rows, keyword_init: true) do
      def any?
        rows.any?
      end

      def filename
        "#{source}.csv"
      end

      def to_csv
        CSV.generate do |csv|
          csv << headers
          rows.each { |row| csv << row }
        end
      end
    end
  end
end
