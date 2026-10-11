# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class ZyzzyvaUnitsAppendTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  COMMANDS = %w[download to_csv use_dsl inject].freeze

  def test_missing_workbook_skips_the_refresh_stages
    with_inbox do |inbox, output_root|
      COMMANDS.each do |command|
        command_output, status = run_stage(command, inbox, output_root)

        assert status.success?, command_output
        assert_match(/\[SKIP\] (ZyzzyvaUnits:|Missing zyzzyva_units\.xlsx)/, command_output)
        refute_includes command_output, '[FAIL]'
      end
    end
  end

  def test_inbox_workbook_is_the_append_source
    with_inbox do |inbox, output_root|
      File.write(File.join(inbox, 'zyzzyva_units.xlsx'), 'workbook')
      command_output, status = run_stage('download', inbox, output_root)
      copied = File.join(output_root, '01_Download', 'zyzzyva_units.xlsx')

      assert status.success?, command_output
      assert_includes command_output, '[APPEND] ZyzzyvaUnits:'
      assert_equal 'workbook', File.read(copied)
    end
  end

  private

  def with_inbox
    Dir.mktmpdir do |root|
      inbox = File.join(root, 'inbox')
      output_root = File.join(root, 'output')
      FileUtils.mkdir_p(inbox)
      yield inbox, output_root
    end
  end

  def run_stage(command, inbox, output_root)
    script = File.join(ROOT, 'script/ruby/data_runner/commands', "#{command}.rb")
    Open3.capture2e(
      { 'DATARUNNER_INBOX' => inbox, 'DATARUNNER_OUTPUT_ROOT' => output_root },
      RbConfig.ruby, script, 'ZyzzyvaUnits'
    )
  end
end
