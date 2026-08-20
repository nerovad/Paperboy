# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../script/ruby/p2m/print_and_inserting_done'

class P2mPrintAndInsertingDoneTest < Minitest::Test
  def test_stages_one_complete_job_and_reports_skipped_jobs
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join('Outputs')
      runner = source.join('DataRunner')
      report = runner.join('report.json')
      create_job(source.join('complete'), '50000001')
      create_job(source.join('incomplete'), '50000002', companion: false)
      create_job(source.join('processed-source'), '50000003')
      FileUtils.mkdir_p(runner.join('02_Processed/50000003'))

      rows = described_class.new(
        source_root: source,
        data_runner_root: runner,
        start_date: '2026-07-01',
        end_date: '2026-07-31',
        report_path: report
      ).call

      statuses = rows.map { |row| row.fetch('status') }
      assert_equal ['staged', 'incomplete', 'already processed'], statuses
      assert runner.join('50000001-companion.csv').file?
      assert runner.join('00_SentToUSPS/Mail.dat_50000001.zip').file?
      assert report.file?
    end
  end

  private

  def described_class = P2m::OmsBackfileStager

  def create_job(directory, number, companion: true)
    FileUtils.mkdir_p(directory)
    paths = [
      directory.join("Mail.dat_#{number}.zip"),
      directory.join("Presort Fields Export_#{number}.txt"),
      directory.join("MoveResults_#{number}.txt")
    ]
    paths << directory.join("#{number}-companion.csv") if companion
    paths.each do |path|
      path.write('fixture')
      FileUtils.touch(path, mtime: Time.new(2026, 7, 15, 12, 0, 0))
    end
  end
end
