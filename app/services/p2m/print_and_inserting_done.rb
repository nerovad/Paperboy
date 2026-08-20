# frozen_string_literal: true

require 'json'
require 'open3'

module P2m
  class PrintAndInsertingDone
    DATA_RUNNER_ROOT = Pathname.new('/mnt/o/Outputs/DataRunner')
    REPORT_PATH = DATA_RUNNER_ROOT.join('p2m_oms_backfill_report.json')
    SCRIPT_PATH = Rails.root.join('script/ruby/p2m/print_and_inserting_done.rb')

    def self.call(start_date:, end_date:)
      command = [
        RbConfig.ruby, SCRIPT_PATH.to_s,
        '--start-date', start_date.iso8601,
        '--end-date', end_date.iso8601,
        '--report', REPORT_PATH.to_s
      ]
      output, status = Open3.capture2e(*command, chdir: Rails.root.to_s)
      raise output.strip unless status.success?

      report
    end

    def self.report
      return unless REPORT_PATH.file?

      JSON.parse(REPORT_PATH.read)
    rescue JSON::ParserError
      nil
    end
  end
end
