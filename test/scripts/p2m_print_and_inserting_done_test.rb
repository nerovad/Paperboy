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
      FileUtils.mkdir_p(runner.join(ENV.fetch('P2M_PROCESSED'), '50000003'))

      rows = described_class.new(
        source_root: source,
        data_runner_root: runner,
        start_date: '2026-07-01',
        end_date: '2026-07-31',
        report_path: report
      ).call

      statuses = rows.map { |row| row.fetch('status') }
      assert_equal ['ready', 'incomplete', 'duplicate OMS number'], statuses
      assert runner.join('50000001-companion.csv').file?
      refute runner.join(ENV.fetch('P2M_SENT_TO_USPS'), 'Mail.dat_50000001.zip').exist?
      assert report.file?
    end
  end

  def test_classifies_conflicts_and_duplicates_by_oms_number
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join('Outputs')
      runner = source.join('DataRunner')
      %w[50000001 50000002 50000003].each do |number|
        create_job(source.join(number), number)
      end
      sent = runner.join(ENV.fetch('P2M_SENT_TO_USPS')).tap(&:mkpath)
      sent.join('Mail.dat_50000001.zip').write('fixture')
      FileUtils.mkdir_p(runner.join(ENV.fetch('P2M_PROCESSED'), '50000002'))
      runner.join('unrelated-staged-input.csv').write('fixture')

      rows = described_class.new(
        source_root: source,
        data_runner_root: runner,
        start_date: '2026-07-01',
        end_date: '2026-07-31',
        report_path: runner.join('report.json')
      ).call

      statuses = rows.map { |row| row.fetch('status') }
      assert_equal ['staging conflict', 'duplicate OMS number', 'ready'], statuses
      refute runner.join('50000003-companion.csv').exist?
    end
  end

  def test_existing_matching_inputs_do_not_create_a_staging_conflict
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join('Outputs')
      runner = source.join('DataRunner')
      job = source.join('job')
      create_job(job, '50000001')
      FileUtils.mkdir_p(runner)
      job.children.reject { |path| path.basename.to_s.start_with?('Mail.dat_') }.each do |path|
        FileUtils.cp(path, runner.join(path.basename), preserve: true)
      end

      rows = described_class.new(
        source_root: source,
        data_runner_root: runner,
        start_date: '2026-07-01',
        end_date: '2026-07-31',
        report_path: runner.join('report.json')
      ).call

      statuses = rows.map { |row| row.fetch('status') }
      assert_equal ['ready'], statuses
      refute runner.join(ENV.fetch('P2M_SENT_TO_USPS'), 'Mail.dat_50000001.zip').exist?
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
