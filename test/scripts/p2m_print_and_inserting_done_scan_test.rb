# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../script/ruby/p2m/print_and_inserting_done'

class P2mPrintAndInsertingDoneScanTest < Minitest::Test
  def test_scan_only_reports_only_oms_numbers_not_staged_or_uploaded
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join('Outputs')
      runner = source.join('DataRunner')
      create_job(source.join('job'), '50000001')
      source.join('job', '50000001-fake.pdf').mkpath
      create_job(source.join('FinalOutput'), '50000002')
      create_job(source.join('staged'), '50000003')
      create_job(source.join('uploaded'), '50000004')
      sent = runner.join(ENV.fetch('P2M_STAGING')).tap(&:mkpath)
      sent.join('Mail.dat_50000003.zip').write('fixture')
      FileUtils.mkdir_p(runner.join(ENV.fetch('P2M_PROCESSED'), '50000004'))
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
      assert_equal '50000001', contents.fetch('files').first.fetch('oms_number')
      assert_equal 4, contents.fetch('files').first.fetch('associated_file_count')
      refute contents.fetch('files').first.key?('associated_files')
      assert_equal 'job', contents.fetch('files').first.fetch('directory')
      assert_equal '2026-07-15 12:00:00', contents.fetch('files').first.fetch('modified_at')
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
