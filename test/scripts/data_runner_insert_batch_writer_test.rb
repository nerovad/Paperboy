# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../script/ruby/data_runner/helpers/insert_batch_writer'

class DataRunnerInsertBatchWriterTest < Minitest::Test
  Result = Class.new do
    define_method(:do) { nil }
  end

  FakeClient = Struct.new(:statements) do
    def execute(sql)
      statements << sql
      Result.new
    end
  end

  def test_flushes_at_row_limit_and_reports_inserted_rows
    client = FakeClient.new([])
    writer = DataRunner::InsertBatchWriter.new(
      client: client,
      prefix: 'INSERT INTO jobs VALUES ',
      max_rows: 2
    )

    %w[(1) (2) (3)].each { |tuple| writer.add(tuple) }

    assert_equal 3, writer.finish
    assert_equal ['INSERT INTO jobs VALUES (1), (2)', 'INSERT INTO jobs VALUES (3)'], client.statements
  end

  def test_flushes_before_byte_limit_is_exceeded
    client = FakeClient.new([])
    writer = DataRunner::InsertBatchWriter.new(
      client: client,
      prefix: 'INSERT INTO jobs VALUES ',
      max_bytes: 7
    )

    %w[(11) (22)].each { |tuple| writer.add(tuple) }

    assert_equal 2, writer.finish
    assert_equal ['INSERT INTO jobs VALUES (11)', 'INSERT INTO jobs VALUES (22)'], client.statements
  end
end
