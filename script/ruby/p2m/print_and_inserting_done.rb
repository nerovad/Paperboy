#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'find'
require 'json'
require 'optparse'
require 'pathname'
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

    def call
      validate!
      rows = findings
      if staging_busy?
        rows.select { |row| row.fetch('status') == 'ready' }.each do |row|
          row['status'] = 'staging conflict'
          row['detail'] = 'DataRunner already contains a staged OMS job.'
        end
      else
        stage_first_ready(rows)
      end
      write_report(rows)
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
      markers.group_by { |marker| oms_number(marker) }.sort.map do |number, matches|
        build_row(number, matches)
      end
    end

    def markers
      matches = []
      Find.find(source_root.to_s) do |name|
        path = Pathname.new(name)
        if path.directory? && inside_data_runner?(path)
          Find.prune
        elsif path.file? && path.basename.to_s.match?(MARKER_PATTERN) && within_range?(path)
          matches << path
        end
      end
      matches
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
      return ['already processed', 'Processed directory exists.'] if processed_path.join(number).directory?
      return ['duplicate marker', "Found #{markers.length} source markers."] if markers.length > 1
      return ['incomplete', "Missing: #{missing.map { |type| label(type) }.join(', ')}."] if missing.any?
      return ['duplicate input', "Multiple: #{duplicates.map { |type| label(type) }.join(', ')}."] if duplicates.any?

      ['ready', 'Ready to stage.']
    end

    def label(type)
      type.to_s.tr('_', ' ')
    end

    def staging_busy?
      staged_names = data_runner_root.children.select(&:file?).map { |path| path.basename.to_s }
      queued = sent_path.children.any? { |path| path.file? && path.basename.to_s.match?(MARKER_PATTERN) }
      queued || staged_names.any? { |name| recognized_name?(name) }
    end

    def recognized_name?(name)
      INPUT_PATTERNS.values.any? { |pattern| name.match?(pattern) }
    end

    def stage_first_ready(rows)
      row = rows.find { |candidate| candidate.fetch('status') == 'ready' }
      return unless row

      input_paths(row).each { |source| copy_without_overwrite(source, data_runner_root.join(source.basename)) }
      marker = Pathname.new(row.fetch('marker'))
      copy_without_overwrite(marker, sent_path.join(marker.basename))
      row['status'] = 'staged'
      row['detail'] = 'Inputs copied; Mail.dat marker published last.'
    rescue StandardError => e
      row['status'] = 'staging failed'
      row['detail'] = e.message
    end

    def input_paths(row)
      row.fetch('inputs').values.flatten.map { |path| Pathname.new(path) }.sort
    end

    def copy_without_overwrite(source, destination)
      raise "destination already exists: #{destination}" if destination.exist?

      FileUtils.cp(source, destination, preserve: true)
    end

    def write_report(rows)
      FileUtils.mkdir_p(report_path.dirname)
      report = {
        'start_date' => start_date.iso8601,
        'end_date' => end_date.iso8601,
        'generated_at' => Time.now.utc.iso8601,
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
  end.parse!
  values[:report_path] ||= File.join(values[:data_runner_root], 'p2m_oms_backfill_report.json')
  values
end

if $PROGRAM_NAME == __FILE__
  arguments = options
  rows = P2m::OmsBackfileStager.new(**arguments).call
  puts JSON.generate('count' => rows.length, 'report' => arguments[:report_path])
end
