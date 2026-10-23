# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../script/ruby/data_runner/helpers/replication_header'

class ReplicationHeaderTest < Minitest::Test
  def test_merge_keeps_destination_names_and_follows_the_live_source
    existing = [
      ['Budget Unit #', 'kept', 'nvarchar(50)', 'NULL', nil],
      ['agency', nil, 'nvarchar(4)', 'NULL', 'drop'],
      ['gone', 'gone', 'int', 'NULL', nil],
      [nil, 'computed', 'int', 'NULL', nil]
    ]
    columns = [
      column('Budget Unit #', 'nvarchar(max)', 'NULL'),
      column('agency', 'nvarchar(4)', 'NOT NULL'),
      column('added', 'date', 'NULL')
    ]

    rows = DataRunner::ReplicationHeader.merge(existing, columns)

    assert_equal [
      ['Budget Unit #', 'kept', 'nvarchar(max)', 'NULL', nil],
      ['agency', nil, 'nvarchar(4)', 'NOT NULL', 'drop'],
      ['added', 'added', 'date', 'NULL', nil],
      [nil, 'computed', 'int', 'NULL', nil]
    ], rows
    assert DataRunner::ReplicationHeader.unchanged?(rows, rows)
    refute DataRunner::ReplicationHeader.unchanged?(existing, rows)
  end

  def test_an_unchanged_header_matches_without_renaming_columns
    rows = [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Budget Unit #', 'Budget Unit #', 'nvarchar(max)', 'NULL', nil]
    ]

    columns = [
      column('ID', 'int', 'IDENTITY(1,1) NOT NULL'),
      column('Budget Unit #', 'nvarchar(max)', 'NULL')
    ]

    assert DataRunner::ReplicationHeader.unchanged?(rows, DataRunner::ReplicationHeader.merge(rows, columns))
  end

  private

  def column(name, data_type, nullability)
    { name: name, data_type: data_type, nullability: nullability }
  end
end
