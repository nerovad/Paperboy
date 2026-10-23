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

    test 'a query matches each character in order on the search columns only' do
      connection = RecordingConnection.new(count: 1, rows: [{ 'bargaining_unit_id' => 'AA', 'description' => 'Smith' }])
      definition = definition_for

      rows = GridReader.rows(definition, offset: 0, limit: 200, query: ' Sm ', connection: connection)

      assert_equal [%w[AA Smith]], rows
      sql = connection.sql.last
      assert_includes sql, "LOWER(CAST([bargaining_unit_id] AS nvarchar(4000))) LIKE '%s%m%'"
      assert_includes sql, "LOWER(CAST([description] AS nvarchar(4000))) LIKE '%s%m%'"
      assert_not_includes sql, '[job_title]'
    end

    test 'gsa employees joins gsa units and job salaries' do
      connection = RecordingConnection.new(count: 1, rows: [{ 'employee_id' => 7, 'last_name' => 'Lee' }])
      definition = GridCatalog.find!('gsa_employees')

      GridReader.rows(definition, offset: 0, limit: 200, query: 'lee', connection: connection)

      sql = connection.sql.last
      assert_includes sql, 'INNER JOIN [units]'
      assert_includes sql, '[employees].[unit] = [units].[unit_id]'
      assert_includes sql, "[units].[agency_id] = 'GSA'"
      assert_includes sql, '[employees].[job_code] = [job_salaries].[job_code_id]'
      assert_includes sql, '[employees].[id] AS [employee_id]'
      assert_includes sql, '[job_salaries].[job_title] AS [job_title]'
      assert_includes sql, '[job_salaries].[rate_min] AS [rate_min]'
      assert_includes sql, '[job_salaries].[rate_max] AS [rate_max]'
      assert_includes sql, 'ORDER BY [employees].[id]'
      assert_includes sql, "LOWER(CAST([units].[agency_id] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([units].[division_id] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([units].[department_id] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([units].[unit_id] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([job_salaries].[job_code_id] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([job_salaries].[job_title] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([employees].[id] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([employees].[first_name] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_includes sql, "LOWER(CAST([employees].[last_name] AS nvarchar(4000))) LIKE '%l%e%e%'"
      assert_not_includes sql, '[employees].[job_title]'
      assert_not_includes sql, '[employees].[email]'
    end

    test 'a blank query does not filter' do
      connection = RecordingConnection.new(count: 0, rows: [])

      GridReader.count(definition_for, query: '   ', connection: connection)

      assert_not_includes connection.sql.last, 'WHERE'
    end

    test 'like wildcards in the query stay literals' do
      connection = RecordingConnection.new(count: 0, rows: [])

      GridReader.count(definition_for, query: '100%_[x]', connection: connection)

      assert_includes connection.sql.last, "LIKE '%1%0%0%[%]%[_]%[[]%x%[]]%'"
    end

    def definition_for(**overrides)
      values = { slug: 'bargaining_units', label: 'Bargaining Units', database: 'GSABSS', schema: 'dbo',
                 table: 'bargaining_units', columns: %w[bargaining_unit_id description],
                 search_columns: %w[bargaining_unit_id description], select_list: nil, from_clause: nil,
                 order_clause: nil, search_expressions: nil }
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

      def quote(value) = "'#{value.to_s.gsub("'", "''")}'"

      def exec_query(statement)
        @sql << statement
        statement.include?('COUNT') ? [{ 'tally' => @count }] : @rows
      end
    end
  end
end
