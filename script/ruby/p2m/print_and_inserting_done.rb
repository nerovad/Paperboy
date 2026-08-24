#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'pathname'
require 'set'
require 'tempfile'
require 'time'

module P2m
  # Scans historical OMS output and safely stages one complete job per run.
  # rubocop:disable Metrics/ClassLength
  class OmsBackfileStager
    OMS_NUMBER = '\\d{8,9}'
    MARKER_PATTERN = /\AMail\.dat_(#{OMS_NUMBER})\.zip\z/i
    INPUT_PATTERNS = {
      companion: /\A(#{OMS_NUMBER})-.+\.csv\z/i,
      daily_presort: /\APresort Fields Export_(#{OMS_NUMBER})\.txt\z/i,
      moveresults: /\AMoveResults_(#{OMS_NUMBER})\.txt\z/i
    }.freeze
    REQUIRED_INPUTS = INPUT_PATTERNS.keys.freeze

    def initialize(source_root:, data_runner_root:, start_date:, end_date:, report_path:)
      @source_root = Pathname.new(source_root).expand_path
      @data_runner_root = Pathname.new(data_runner_root).expand_path
      @start_date = Date.iso8601(start_date.to_s)
      @end_date = Date.iso8601(end_date.to_s)
      @report_path = Pathname.new(report_path).expand_path
    end

    def call(stage: true)
      validate!
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rows = stage ? findings : scan_files
      elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      if stage
        mark_staging_conflicts(rows)
        stage_first_ready(rows) if queued_oms_numbers.empty?
      end
      write_report(rows, elapsed_seconds: elapsed_seconds, review_pending: !stage)
      rows
    end

    private

    attr_reader :source_root, :data_runner_root, :start_date, :end_date, :report_path

    def validate!
      raise ArgumentError, 'start date must be on or before end date' if start_date > end_date
      raise ArgumentError, "source directory not found: #{source_root}" unless source_root.directory?

      FileUtils.mkdir_p(sent_path)
      FileUtils.mkdir_p(processed_path)
    end

    def findings
      marker_paths = markers
      record_files(marker_paths)
      marker_paths.group_by { |marker| oms_number(marker) }.sort.map do |number, matches|
        build_row(number, matches)
      end
    end

    def scan_files
      available_markers = markers.reject { |marker| unavailable_oms_numbers.include?(oms_number(marker)) }
      record_files(available_markers)
      []
    end

    def record_files(marker_paths)
      @files = marker_paths.sort_by { |path| oms_number(path) }.reverse.map do |path|
        {
          'name' => path.basename.to_s,
          'oms_number' => oms_number(path),
          'modified_at' => path.mtime.strftime('%Y-%m-%d %H:%M:%S'),
          'directory' => path.dirname.relative_path_from(source_root).to_s
        }
      end
      @found_count = @files.length
    end

    def markers
      output, error, status = Open3.capture3(*fd_command)
      raise "Mail.dat search failed: #{error.strip}" unless status.success?

      output.split("\0").filter_map do |name|
        path = Pathname.new(name)
        path if !inside_data_runner?(path) && path.basename.to_s.match?(MARKER_PATTERN) && within_range?(path)
      end
    end

    def fd_command
      [
        'fd', '--no-ignore', '--type', 'f', '--extension', 'zip', '--print0',
        '--exclude', 'FinalOutput',
        '--changed-within', start_date.iso8601,
        '--changed-before', (end_date + 1).iso8601,
        "^Mail\\.dat_#{OMS_NUMBER}\\.zip$", source_root.to_s
      ]
    end

    def within_range?(path) = path.mtime.to_date.between?(start_date, end_date)

    def inside_data_runner?(path)
      path.to_s == data_runner_root.to_s || path.to_s.start_with?("#{data_runner_root}/")
    end

    def oms_number(marker)
      marker.basename.to_s.match(MARKER_PATTERN)[1]
    end

    def build_row(number, marker_matches)
      marker = marker_matches.first
      inputs = classified_inputs(marker.dirname, number)
      missing = REQUIRED_INPUTS.select { |type| inputs.fetch(type).empty? }
      duplicates = %i[daily_presort moveresults].select { |type| inputs.fetch(type).length > 1 }
      status, detail = status_for(number, marker_matches, missing, duplicates)

      {
        'oms_number' => number,
        'mail_date' => marker.mtime.to_date.iso8601,
        'source_directory' => marker.dirname.to_s,
        'status' => status,
        'detail' => detail,
        'marker' => marker.to_s,
        'inputs' => inputs.transform_values { |paths| paths.map(&:to_s) }
      }
    end

    def classified_inputs(directory, number)
      INPUT_PATTERNS.to_h do |type, pattern|
        matches = directory.children.select do |path|
          match = path.file? && path.basename.to_s.match(pattern)
          match && match[1] == number
        end
        [type, matches.sort]
      end
    end

    def status_for(number, markers, missing, duplicates)
      return ['duplicate OMS number', 'OMS number exists in 02_Processed.'] if processed_path.join(number).directory?
      return ['duplicate marker', "Found #{markers.length} source markers."] if markers.length > 1
      return ['incomplete', "Missing: #{missing.map { |type| label(type) }.join(', ')}."] if missing.any?
      return ['duplicate input', "Multiple: #{duplicates.map { |type| label(type) }.join(', ')}."] if duplicates.any?

      ['ready', 'Ready to stage.']
    end

    def label(type)
      type.to_s.tr('_', ' ')
    end

    def mark_staging_conflicts(rows)
      conflicts = queued_oms_numbers
      rows.select { |row| row.fetch('status') == 'ready' && conflicts.include?(row.fetch('oms_number')) }.each do |row|
        row['status'] = 'staging conflict'
        row['detail'] = 'OMS number exists in 00_SentToUSPS.'
      end
    end

    def queued_oms_numbers
      @queued_oms_numbers ||= sent_path.children.filter_map do |path|
        match = path.file? && path.basename.to_s.match(MARKER_PATTERN)
        match[1] if match
      end.to_set
    end

    def unavailable_oms_numbers
      @unavailable_oms_numbers ||= queued_oms_numbers | processed_oms_numbers
    end

    def processed_oms_numbers
      processed_path.children.filter_map do |path|
        path.basename.to_s if path.directory? && path.basename.to_s.match?(/\A#{OMS_NUMBER}\z/)
      end.to_set
    end

    def stage_first_ready(rows)
      row = rows.find { |candidate| candidate.fetch('status') == 'ready' }
      return unless row

      input_paths(row).each { |source| copy_without_overwrite(source, data_runner_root.join(source.basename)) }
    rescue StandardError => e
      row['status'] = 'staging failed'
      row['detail'] = e.message
    end

    def input_paths(row)
      row.fetch('inputs').values.flatten.map { |path| Pathname.new(path) }.sort
    end

    def copy_without_overwrite(source, destination)
      return if matching_file_metadata?(source, destination)
      raise "destination already exists with different contents: #{destination}" if destination.exist?

      FileUtils.cp(source, destination, preserve: true)
    end

    def matching_file_metadata?(source, destination)
      destination.file? && source.size == destination.size && source.mtime == destination.mtime
    end

    def write_report(rows, elapsed_seconds:, review_pending:)
      FileUtils.mkdir_p(report_path.dirname)
      report = {
        'source_root' => source_root.to_s,
        'start_date' => start_date.iso8601,
        'end_date' => end_date.iso8601,
        'generated_at' => Time.now.utc.iso8601,
        'found_count' => @found_count,
        'files' => @files,
        'search_seconds' => elapsed_seconds.round(3),
        'review_pending' => review_pending,
        'rows' => rows
      }
      Tempfile.create(['p2m-oms-report', '.json'], report_path.dirname) do |temp|
        temp.write(JSON.pretty_generate(report))
        temp.flush
        FileUtils.mv(temp.path, report_path)
      end
    end

    def sent_path = data_runner_root.join('00_SentToUSPS')
    def processed_path = data_runner_root.join('02_Processed')
  end
  # rubocop:enable Metrics/ClassLength
end

def options
  values = {
    source_root: '/mnt/o/Outputs',
    data_runner_root: '/mnt/o/Outputs/DataRunner'
  }
  OptionParser.new do |parser|
    parser.on('--source-root PATH') { |value| values[:source_root] = value }
    parser.on('--data-runner-root PATH') { |value| values[:data_runner_root] = value }
    parser.on('--start-date DATE') { |value| values[:start_date] = value }
    parser.on('--end-date DATE') { |value| values[:end_date] = value }
    parser.on('--report PATH') { |value| values[:report_path] = value }
    parser.on('--scan-only') { values[:scan_only] = true }
  end.parse!
  values[:report_path] ||= File.join(values[:data_runner_root], 'p2m_oms_backfill_report.json')
  values
end

if $PROGRAM_NAME == __FILE__
  arguments = options
  scan_only = arguments.delete(:scan_only)
  rows = P2m::OmsBackfileStager.new(**arguments).call(stage: !scan_only)
  puts JSON.generate('count' => rows.length, 'report' => arguments[:report_path])
end
