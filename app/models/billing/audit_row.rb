# frozen_string_literal: true

module Billing
  # Presents one TC60 row with the columns that failed an audit check.
  class AuditRow
    Cell = Data.define(:column, :value, :invalid)

    attr_reader :attributes

    def initialize(attributes, invalid_columns:)
      @attributes = attributes
      @invalid_columns = invalid_columns.to_set { |column| column.to_s.upcase }
    end

    def columns
      attributes.keys
    end

    def cells
      attributes.map do |column, value|
        Cell.new(column: column, value: value,
                 invalid: invalid_columns.include?(column.to_s.upcase))
      end
    end

    private

    attr_reader :invalid_columns
  end
end
