# frozen_string_literal: true

require 'test_helper'

class DataRunnerDependentClearTest < ActiveSupport::TestCase
  Entry = Data.define(:key, :config)

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

  test 'truncates foreign-key children before deleting a delete_insert child' do
    clients = Hash.new { |hosts, host| hosts[host] = FakeClient.new }
    messages = DataRunner::DependentTruncate.perform(
      %w[Employee Activity Session Interval],
      entries: entries,
      connector: ->(host) { clients[host] }
    )

    assert_equal [
      '[OK] Interval: truncated sql22.example.Paperboy.scan.TimeTrackingInterval before dependency inject',
      '[OK] Session: deleted sql22.example.Paperboy.scan.TimeTrackingSession before dependency inject'
    ], messages
    sql = clients['sql22.example'].sql
    truncate_at = sql.index { |statement| statement.include?('TRUNCATE TABLE') }
    delete_at = sql.index { |statement| statement.include?('DELETE FROM') }
    assert_operator truncate_at, :<, delete_at
  end

  private

  def entries
    [
      Entry.new(key: 'Employee', config: row('BoxStatusEmployee', nil, :delete_insert)),
      Entry.new(key: 'Session', config: row('TimeTrackingSession', %w[Employee Activity], :delete_insert)),
      Entry.new(key: 'Interval', config: row('TimeTrackingInterval', 'Session', :truncate_insert))
    ]
  end

  def row(table, dependency, mode)
    {
      dependency: dependency,
      database_connections: [
        { host: 'sql22.example', database: 'Paperboy', schema: 'scan', table: table,
          inject: { mode: mode, delete_where: '1 = 1' } }
      ]
    }
  end
end
