# frozen_string_literal: true

require 'test_helper'

module HumanResources
  class GridReaderTest < ActiveSupport::TestCase
    Definition = GridCatalog::Definition

    test 'reads one GSABSS page with quoted dsl identifiers' do
      connection = RecordingConnection.new(count: 2, rows: [{ 'Bargaining_Unit_Id' => 'A', 'description' => 'Alpha' }])
      definition = definition_for

      assert_equal 2, GridReader.count(definition, connection: connection)
      assert_equal [%w[A Alpha]], GridReader.rows(definition, offset: 0, limit: 200, connection: connection)
      assert_includes connection.sql.last, 'FROM [dbo].[bargaining_units]'
      assert_includes connection.sql.last, '[bargaining_unit_id]'
      assert_includes connection.sql.last, 'OFFSET 0 ROWS FETCH NEXT 200 ROWS ONLY'
    end

    test 'refuses an identifier or database outside the dsl contract' do
      connection = RecordingConnection.new(count: 0, rows: [])

      assert_raises(ArgumentError) { GridReader.count(definition_for(table: 'units;drop'), connection: connection) }
      assert_raises(ArgumentError) { GridReader.count(definition_for(database: 'Paperboy'), connection: connection) }
      assert_empty connection.sql
    end

    def definition_for(**overrides)
      values = { slug: 'bargaining_units', label: 'Bargaining Units', database: 'GSABSS', schema: 'dbo',
                 table: 'bargaining_units', columns: %w[bargaining_unit_id description] }
      Definition.new(**values, **overrides)
    end

    # Stands in for the GSABSS connection and records the statements.
    class RecordingConnection
      attr_reader :sql

      def initialize(count:, rows:)
        @count = count
        @rows = rows
        @sql = []
      end

      def quote_column_name(name) = "[#{name}]"

      def exec_query(statement)
        @sql << statement
        statement.include?('COUNT') ? [{ 'tally' => @count }] : @rows
      end
    end
  end
end
