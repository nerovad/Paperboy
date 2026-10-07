# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'securerandom'
require_relative '../../../lib/paperboy/search_cancellation'

module P2m
  class PrintAndInsertingDone
    DATA_RUNNER_ROOT = Paths::DATA_RUNNER_ROOT
    REPORT_DIRECTORY = DATA_RUNNER_ROOT.join('p2m_search_reports')
    SCRIPT_PATH = Rails.root.join('script/ruby/p2m/print_and_inserting_done.rb')

    def self.scan(start_date:, end_date:, cancellation_token: nil, report_directory: nil)
      run(start_date: start_date, end_date: end_date, scan_only: true,
          cancellation_token: cancellation_token, report_directory: report_directory)
    end

    def self.historical_jobs(start_date:, end_date:, report_path:)
      command = [
        RbConfig.ruby, SCRIPT_PATH.to_s,
        '--start-date', start_date.iso8601,
        '--end-date', end_date.iso8601,
        '--report', report_path.to_s,
        '--historical-jobs'
      ]
      output, status = Open3.capture2e(*command, chdir: Rails.root.to_s)
      raise output.strip unless status.success?

      JSON.parse(report_path.read).fetch('rows')
    end

    def self.run(start_date:, end_date:, scan_only: false, cancellation_token: nil, report_directory: nil)
      report_path = nil
      report_path = allocate_report_path(report_directory)
      command = [
        RbConfig.ruby, SCRIPT_PATH.to_s,
        '--start-date', start_date.iso8601,
        '--end-date', end_date.iso8601,
        '--report', report_path.to_s
      ]
      command << '--scan-only' if scan_only
      command += ['--cancel-token', cancellation_token] if cancellation_token
      output, status = Open3.capture2e(*command, chdir: Rails.root.to_s)
      cancelled = cancellation_token && Paperboy::SearchCancellation.cancelled?(cancellation_token)
      raise Paperboy::SearchCancellation::Cancelled if cancelled
      raise output.strip unless status.success?

      read_report(report_path)
    ensure
      FileUtils.rm_f(report_path) if report_path
      Paperboy::SearchCancellation.cleanup!(cancellation_token) if cancellation_token
    end

    def self.allocate_report_path(report_directory)
      directory = Pathname.new(report_directory || REPORT_DIRECTORY)
      FileUtils.mkdir_p(directory)
      directory.join("search-#{SecureRandom.uuid}.json")
    end

    def self.read_report(report_path)
      return unless report_path.file?

      JSON.parse(report_path.read)
    rescue JSON::ParserError
      nil
    end
    private_class_method :run, :allocate_report_path, :read_report
  end
end
