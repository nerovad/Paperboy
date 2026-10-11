# frozen_string_literal: true

module Pfa
  module Grid
    # Small presentation contract for tabular data. The caller supplies rows
    # after applying its own access rules and query behavior.
    class Table
      # Rows rendered into one browser page. Larger sets page on the server
      # (Records) or stop the preview (DataRunner) so the document stays bounded.
      PAGE_ROWS = 200

      Column = Struct.new(:key, :label, :sort_type, keyword_init: true)

      attr_reader :columns, :rows

      def initialize(columns:, rows:)
        @columns = Array(columns).map.with_index do |column, index|
          values = column.respond_to?(:to_h) ? column.to_h : { label: column }
          Column.new(key: values[:key] || index, label: values[:label].to_s,
                     sort_type: values[:sort_type] || :text).freeze
        end.freeze
        @rows = Array(rows).map do |row|
          values = Array(row).first(@columns.size)
          values.fill(nil, values.size...@columns.size).freeze
        end.freeze
      end
    end
  end
end
