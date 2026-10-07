# frozen_string_literal: true

require 'test_helper'

module P2m
  class PrintAndInsertingDoneTest < ActiveSupport::TestCase
    test 'each scan reads only the report it wrote' do
      Dir.mktmpdir do |directory|
        reports = {}
        runner = lambda do |*command, **_options|
          path = report_path(command)
          payload = { 'files' => [{ 'oms_number' => path.basename('.*').to_s }] }
          path.write(JSON.generate(payload))
          reports[path] = payload
          ['', success]
        end

        first = nil
        second = nil
        Open3.stub(:capture2e, runner) do
          first = PrintAndInsertingDone.scan(start_date: quarter.begin, end_date: quarter.end,
                                             report_directory: directory)
          second = PrintAndInsertingDone.scan(start_date: quarter.begin, end_date: quarter.end,
                                              report_directory: directory)
        end

        assert_equal 2, reports.size
        assert_equal reports.keys.first.basename('.*').to_s, first.dig('files', 0, 'oms_number')
        assert_equal reports.keys.to_a[1].basename('.*').to_s, second.dig('files', 0, 'oms_number')
        refute_equal first.dig('files', 0, 'oms_number'), second.dig('files', 0, 'oms_number')
        reports.each_key do |path|
          refute_equal 'p2m_oms_backfill_report.json', path.basename.to_s
          refute_path_exists path
        end
      end
    end

    test 'a failed scan removes its report' do
      Dir.mktmpdir do |directory|
        written = nil
        runner = lambda do |*command, **_options|
          written = report_path(command)
          written.write('{}')
          ['Mail.dat search failed', failure]
        end

        Open3.stub(:capture2e, runner) do
          error = assert_raises(RuntimeError) do
            PrintAndInsertingDone.scan(start_date: quarter.begin, end_date: quarter.end,
                                       report_directory: directory)
          end
          assert_equal 'Mail.dat search failed', error.message
        end

        refute_path_exists written
      end
    end

    private

    def quarter
      Date.new(2026, 7, 1)..Date.new(2026, 9, 30)
    end

    def report_path(command)
      Pathname.new(command[command.index('--report') + 1])
    end

    def success
      Struct.new(:success?).new(true)
    end

    def failure
      Struct.new(:success?).new(false)
    end
  end
end
