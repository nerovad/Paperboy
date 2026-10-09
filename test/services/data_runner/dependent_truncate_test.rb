# frozen_string_literal: true

require 'test_helper'

class DataRunnerDependentTruncateTest < ActiveSupport::TestCase
  Entry = Struct.new(:key, :config)

  FakeClient = Struct.new(:sql) do
    def initialize
      super([])
    end

    def execute(statement)
      sql << statement
      self
    end

    def do; end

    def close; end
  end

  test 'commits a truncate for a dependent truncate_insert table before inject' do
    clients = Hash.new { |hosts, host| hosts[host] = FakeClient.new }
    messages = DataRunner::DependentTruncate.perform(
      %w[Gsabss_agencies Gsabss_tc60 Gsabss_tc60_types],
      entries: sample_entries,
      connector: ->(host) { clients[host] }
    )

    assert_equal ['[OK] Gsabss_tc60: truncated sql22.example.Paperboy.bss.TC60 before dependency inject'], messages
    assert_equal [
      'SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; ' \
      'SET CONCAT_NULL_YIELDS_NULL ON; SET QUOTED_IDENTIFIER ON; SET NUMERIC_ROUNDABORT OFF;',
      'USE [Paperboy]',
      'BEGIN TRAN',
      'TRUNCATE TABLE [bss].[TC60]',
      'COMMIT TRAN'
    ], clients['sql22.example'].sql
    assert_not clients.key?('types.example')
  end

  test 'leaves a dependent table in place when its dependency is not in the run' do
    called = false
    messages = DataRunner::DependentTruncate.perform(
      ['Gsabss_tc60'],
      entries: sample_entries,
      connector: lambda { |_host|
        called = true
        FakeClient.new
      }
    )

    assert_empty messages
    assert_not called
  end

  private

  def sample_entries
    [
      Entry.new('Gsabss_agencies', replication('agencies', nil)),
      Entry.new('Gsabss_tc60', replication('TC60', 'Gsabss_tc60_types')),
      Entry.new('Gsabss_tc60_types', types_config),
      Entry.new('ZyzzyvaUnits', append_config)
    ]
  end

  def replication(table, dependency)
    {
      dependency: dependency,
      database_connections: [
        { host: 'sql22.example', database: 'Paperboy', schema: 'bss', table: table,
          inject: { mode: :truncate_insert } }
      ]
    }
  end

  def types_config
    {
      database_connections: [
        { host: 'types.example', database: 'Paperboy', schema: 'bss', table: 'TC60_Types',
          inject: { mode: :delete_insert, delete_where: '1 = 1' } }
      ]
    }
  end

  def append_config
    {
      dependency: 'Units',
      database_connections: [
        { host: 'sql22.example', database: 'GSABSS', schema: 'dbo', table: 'units',
          inject: { mode: :append } }
      ]
    }
  end
end
