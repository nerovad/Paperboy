# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../script/ruby/p2m/print_and_inserting_done'

class P2mPrintAndInsertingDoneScanTest < Minitest::Test
  def test_scan_only_reports_files_without_staging_inputs
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join('Outputs')
      runner = source.join('DataRunner')
      create_job(source.join('job'), '50000001')
      report = runner.join('report.json')

      rows = P2m::OmsBackfileStager.new(
        source_root: source,
        data_runner_root: runner,
        start_date: '2026-07-01',
        end_date: '2026-07-31',
        report_path: report
      ).call(stage: false)

      assert_empty rows
      refute runner.join('50000001-companion.csv').exist?
      contents = JSON.parse(report.read)
      assert contents.fetch('review_pending')
      assert_equal source.to_s, contents.fetch('source_root')
      assert_equal 1, contents.fetch('found_count')
      names = contents.fetch('files').map { |file| file.fetch('name') }
      assert_equal ['Mail.dat_50000001.zip'], names
      assert_operator contents.fetch('search_seconds'), :>=, 0
    end
  end

  private

  def create_job(directory, number)
    FileUtils.mkdir_p(directory)
    [
      directory.join("Mail.dat_#{number}.zip"),
      directory.join("Presort Fields Export_#{number}.txt"),
      directory.join("MoveResults_#{number}.txt"),
      directory.join("#{number}-companion.csv")
    ].each do |path|
      path.write('fixture')
      FileUtils.touch(path, mtime: Time.new(2026, 7, 15, 12, 0, 0))
    end
  end
end
