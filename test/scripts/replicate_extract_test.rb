# frozen_string_literal: true

require 'minitest/autorun'
require 'time'
require_relative '../../script/ruby/data_runner/constants/workflow'
require_relative '../../script/ruby/data_runner/helpers/replicate_extract'

class ReplicateExtractTest < Minitest::Test
  def test_streams_one_row_at_a_time_into_a_character_file
    note = "a, \"b\"\nc"
    when_at = Time.utc(2026, 10, 10, 15, 23, 22)
    cfg = {
      header: [
        ['Note', 'Note', 'varchar(100)', 'NULL', nil],
        ['Amount', 'Amount', 'bigint', 'NULL', nil],
        ['When', 'When', 'datetime2(7)', 'NULL', nil],
        ['ID', 'ID', 'int', 'IDENTITY(0,1) NOT NULL', nil]
      ]
    }
    client = RecordingClient.new(
      [
        [note, 1234, when_at, 7],
        ['', nil, nil, nil]
      ]
    )

    rows = write_rows(client, cfg)

    assert_equal({ cache_rows: false, as: :array }, client.result.each_options)
    assert_equal 'SELECT [Note], [Amount], [When], [ID] FROM [dbo].[Companion]', client.sql
    assert_equal [
      %w[Note Amount When ID],
      [note, '1234', '2026-10-10 15:23:22', '7'],
      ['', '', '', '2']
    ], rows
  end

  def test_gsap2m_refresh_uses_replicate_steps
    root = File.expand_path('../../config/data_runner/dsl/gsap2m', __dir__)
    files = Dir[File.join(root, '*.rb')]

    assert_operator files.length, :>=, 24
    files.each do |path|
      source = File.read(path)
      assert_includes source, 'steps: Workflow::REPLICATE_STEPS', path
      assert_includes source, "scheduled: {\n        enabled: false,", path
      refute_includes source, 'MANUAL_STEPS', path
      refute_includes source, 'SCHEDULED_STEPS', path
      assert_includes source, 'strategy: :replicate', path
    end
  end

  private

  def write_rows(client, cfg)
    require 'tmpdir'
    Dir.mktmpdir do |directory|
      @applied = File.join(directory, 'applied.csv')
      sql = DataRunner::ReplicateExtract.query_sql('dbo', 'Companion', DataRunner::ReplicateExtract.source_columns(cfg))
      File.open(@applied, 'wb') do |io|
        DataRunner::ReplicateExtract.write_query(
          client, sql, io, cfg, columns: DataRunner::ReplicateExtract.source_columns(cfg), dsl: 'Sample'
        )
      end
      bytes = File.binread(@applied)
      assert_includes bytes, "\x1E".b
      rows = []
      BcpCharacterFile.each_row(@applied) { |row| rows << row }
      rows
    end
  end
end

class RecordingResult
  attr_reader :each_options

  def initialize(rows)
    @rows = rows
  end

  def each(options = {}, &block)
    @each_options = options
    @rows.each(&block)
  end
end

class RecordingClient
  attr_reader :sql, :result

  def initialize(rows)
    @rows = rows
  end

  def execute(sql)
    @sql = sql
    @result = RecordingResult.new(@rows)
  end
end
