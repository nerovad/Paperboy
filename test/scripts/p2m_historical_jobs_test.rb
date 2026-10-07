# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../script/ruby/p2m/print_and_inserting_done'

class P2mHistoricalJobsTest < Minitest::Test
  def test_lists_every_marker_without_moving_files
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join('Outputs')
      runner = source.join('DataRunner')
      shared = source.join('shared')
      create_job(shared, '50000001')
      labels = shared.join('50000001-tray-labels.pdf')
      labels.write('labels')
      FileUtils.touch(labels, mtime: Time.new(2026, 7, 15, 12, 0, 0))
      shared.join('50000009-other.csv').write('other')
      create_job(source.join('archived'), '50000002')
      FileUtils.mkdir_p(runner.join(ENV.fetch('P2M_PROCESSED'), '50000002'))
      create_job(source.join('old'), '50000003')
      source.join('old').children.each { |path| FileUtils.touch(path, mtime: Time.new(2026, 6, 1, 12, 0, 0)) }

      rows = stager(source, runner).historical_jobs
      numbers = rows.map { |row| row.fetch('oms_number') }

      assert_equal(%w[50000001 50000002], numbers)
      assert_equal 'duplicate OMS number', rows[1].fetch('status')
      files = rows.first.fetch('files').map { |path| File.basename(path) }
      assert_includes files, 'Mail.dat_50000001.zip'
      assert_includes files, '50000001-tray-labels.pdf'
      refute_includes files, '50000009-other.csv'
      assert shared.join('Mail.dat_50000001.zip').exist?
      refute runner.join('50000001-companion.csv').exist?
    end
  end

  def test_command_writes_the_report_without_staging
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join('Outputs')
      runner = source.join('DataRunner')
      report = runner.join('report.json')
      create_job(source.join('complete'), '50000001')
      script = File.expand_path('../../script/ruby/p2m/print_and_inserting_done.rb', __dir__)
      output, status = Open3.capture2e(
        RbConfig.ruby, script,
        '--source-root', source.to_s, '--data-runner-root', runner.to_s,
        '--start-date', '2026-07-01', '--end-date', '2026-09-30',
        '--report', report.to_s, '--historical-jobs'
      )

      assert status.success?, output
      rows = JSON.parse(report.read).fetch('rows')
      assert_equal(['50000001'], rows.map { |row| row.fetch('oms_number') })
      assert rows.first.fetch('files').any?
      refute runner.join('50000001-companion.csv').exist?
    end
  end

  private

  def stager(source, runner)
    P2m::OmsBackfileStager.new(
      source_root: source, data_runner_root: runner,
      start_date: '2026-07-01', end_date: '2026-09-30',
      report_path: runner.join('report.json')
    )
  end

  def create_job(directory, number)
    FileUtils.mkdir_p(directory)
    %W[Mail.dat_#{number}.zip #{number}-companion.csv Presort\ Fields\ Export_#{number}.txt
       MoveResults_#{number}.txt].each do |name|
      path = directory.join(name)
      path.write('fixture')
      FileUtils.touch(path, mtime: Time.new(2026, 7, 15, 12, 0, 0))
    end
  end
end
