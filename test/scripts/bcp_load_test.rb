# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../script/ruby/data_runner/helpers/bcp_load'
require_relative '../../script/ruby/data_runner/helpers/bcp_stage'

class BcpLoadTest < Minitest::Test
  def test_command_uses_the_applied_character_file_switches
    argv = DataRunner::BcpLoad.command(
      executable: 'bcp',
      qualified_table: '[Paperboy].[p2m].[Companion_bcp_stage]',
      file: 'gsap2m_companion.csv',
      server: 'gsa-sql22-tst.ent.co.ventura.ca.us',
      trusted: true
    )

    assert_equal [
      'bcp', '[Paperboy].[p2m].[Companion_bcp_stage]', 'in', 'gsap2m_companion.csv',
      '-S', 'gsa-sql22-tst.ent.co.ventura.ca.us',
      '-c', '-C', '65001',
      '-t', '0x1F', '-r', '0x1E',
      '-F', '2', '-E',
      '-b', '10000',
      '-u',
      '-T'
    ], argv
  end

  def test_sql_auth_command_hides_the_password_in_the_display
    argv = DataRunner::BcpLoad.command(
      executable: 'bcp',
      qualified_table: '[GSABSS].[dbo].[Units]',
      file: 'units.csv',
      server: 'GSASQL16,1433',
      trusted: false,
      username: 'GSAETL',
      password: 'secret'
    )

    assert_includes argv, '-U'
    assert_includes argv, '-P'
    assert_includes DataRunner::BcpLoad.display(argv), '-P ***'
    refute_includes DataRunner::BcpLoad.display(argv), 'secret'
  end

  def test_failed_bcp_raises_and_does_not_return
    Dir.mktmpdir do |directory|
      executable = File.join(directory, 'bcp')
      File.write(executable, "#!/bin/sh\necho 'rows rejected' >&2\nexit 1\n")
      File.chmod(0o755, executable)
      argv = DataRunner::BcpLoad.command(
        executable: executable,
        qualified_table: '[Paperboy].[p2m].[Companion]',
        file: 'companion.csv',
        server: 'gsa-sql22-tst',
        trusted: false,
        username: 'GSAETL',
        password: 'secret'
      )

      error = assert_raises(RuntimeError) { DataRunner::BcpLoad.run!(argv) }
      assert_match(/bcp failed \(1\)/, error.message)
      assert_match(/rows rejected/, error.message)
    end
  end

  def test_insert_names_applied_columns_and_converts_blank_numbers_to_null
    sql = DataRunner::BcpStage.insert_sql(
      'p2m', 'Companion', 'Companion_bcp_ab12',
      %w[Note Amount],
      { 'Note' => 'varchar(100)', 'Amount' => 'bigint' }
    )

    assert_includes sql, 'INSERT INTO [p2m].[Companion] ([Note], [Amount])'
    assert_includes sql, 'SELECT stage.[Note], CONVERT(bigint, NULLIF(stage.[Amount], N\'\'))'
    assert_includes sql, 'FROM [p2m].[Companion_bcp_ab12] AS stage'
  end

  def test_insert_keeps_empty_not_null_strings_and_restores_binary
    sql = DataRunner::BcpStage.insert_sql(
      'scan', 'TimeTrackingRequest', 'TimeTrackingRequest_bcp_ab12',
      %w[Comment PayloadHash Note],
      {
        'Comment' => { data_type: 'nvarchar(1000)', nullability: 'NOT NULL' },
        'PayloadHash' => { data_type: 'binary(32)', nullability: 'NOT NULL' },
        'Note' => { data_type: 'nvarchar(100)', nullability: 'NULL' }
      }
    )

    assert_includes sql, 'ISNULL(stage.[Comment], N\'\')'
    assert_includes sql, 'CONVERT(binary(32), NULLIF(stage.[PayloadHash], N\'\'), 2)'
    assert_includes sql, 'stage.[Note]'
    refute_includes sql, 'ISNULL(stage.[Note]'
  end
end
