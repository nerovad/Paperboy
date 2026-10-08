# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/paperboy/ci_database'

class CiDatabaseTest < Minitest::Test
  # Answers the catalog queries the way SQL Server would and quotes the way
  # the sqlserver adapter does, so no database is needed.
  class FakeConnection
    attr_reader :executed

    def initialize(database, rows = {})
      @database = database
      @rows = rows
      @executed = []
    end

    def select_value(sql)
      raise ArgumentError, sql unless sql == 'SELECT DB_NAME()'

      @database
    end

    def select_rows(sql)
      @rows.fetch(sql, [])
    end

    def execute(sql)
      @executed << sql
    end

    def quote_column_name(name)
      "[#{name.gsub(']', ']]')}]"
    end
  end

  CI = Paperboy::CiDatabase

  def test_only_names_ending_in_ci_are_ci_databases
    assert CI.ci_database?('Paperboy_CI')
    %w[Paperboy_Test Paperboy_Dev Paperboy_Prod GSABSS Paperboy_ci Paperboy_CI_old CI].each do |name|
      refute CI.ci_database?(name), name
    end
    refute CI.ci_database?(nil)
    refute CI.ci_database?('')
  end

  def test_guard_refuses_other_databases
    assert_equal 'Paperboy_CI', CI.guard!('Paperboy_CI')
    error = assert_raises(CI::Refused) { CI.guard!('Paperboy_Test') }
    assert_includes error.message, 'Paperboy_Test'
    assert_raises(CI::Refused) { CI.guard!(nil) }
  end

  def test_reset_refuses_a_non_ci_configuration_before_connecting
    config = Struct.new(:database).new('Paperboy_Dev')

    assert_raises(CI::Refused) { CI.reset!(config) }
  end

  def test_empty_refuses_when_the_connected_database_is_not_ci
    connection = FakeConnection.new('Paperboy_Prod', CI::OBJECTS['TABLE'] => [%w[dbo users]])

    assert_raises(CI::Refused) { CI.new(connection).empty! }
    assert_empty connection.executed
  end

  def test_empty_drops_foreign_keys_then_objects_then_schemas
    connection = FakeConnection.new('Paperboy_CI', {
                                      CI::FOREIGN_KEYS => [%w[aim invoice_events fk_events_invoice]],
                                      CI::OBJECTS['VIEW'] => [%w[dbo open_forms]],
                                      CI::OBJECTS['TABLE'] => [%w[aim invoices], %w[dbo users]],
                                      CI::SCHEMAS => [%w[aim]]
                                    })

    CI.new(connection).empty!

    assert_equal [
      'ALTER TABLE [aim].[invoice_events] DROP CONSTRAINT [fk_events_invoice]',
      'DROP VIEW [dbo].[open_forms]',
      'DROP TABLE [aim].[invoices]',
      'DROP TABLE [dbo].[users]',
      'DROP SCHEMA [aim]'
    ], connection.executed
  end

  def test_identifiers_are_quoted_through_the_connection
    connection = FakeConnection.new('Paperboy_CI', CI::OBJECTS['TABLE'] => [['dbo', 'odd]name']])

    assert_equal ['DROP TABLE [dbo].[odd]]name]'], CI.new(connection).drop_statements
  end
end
