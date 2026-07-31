#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'pathname'
require 'tempfile'
require 'time'

# Assemble the files exported by OMS into one consistently named set per
# eight- or nine-digit OMS number selected by a Mail.dat marker.
#
# Usage:
#   ruby script/ruby/data_runner/orchestration/preprocess/oms.rb \
#     ROOT_PATH SENT_PATH OUTPUT_PATH
#
# Generated files are written to OUTPUT_PATH:
#   companions.csv
#   dailypresorts.csv
#   moveresults.csv
#
# Companion inputs have names like NNNNNNNN-...-.csv. Their common header is
# written once and their data rows are appended in filename order.
# MoveResults_NNNNNNNN.txt is treated as UTF-16LE tab-delimited text and
# serialized as standards-compliant CSV.
OMS_NUMBER_PATTERN = '\d{8,9}'
MARKER_PATTERN = /\AMail\.dat_(#{OMS_NUMBER_PATTERN})\.zip\z/i
COMPANION_PATTERN = /\A(#{OMS_NUMBER_PATTERN})-.+\.csv\z/i
MOVE_RESULTS_PATTERN = /\AMoveResults_(#{OMS_NUMBER_PATTERN})\.txt\z/i
DAILY_PRESORT_PATTERN = /\APresort Fields Export_(#{OMS_NUMBER_PATTERN})\.txt\z/i
METADATA_HEADER = %w[omsnumber importdatetime].freeze
OUTPUT_FILES = %w[companions.csv dailypresorts.csv moveresults.csv].freeze

def paths
  raise "usage: #{$PROGRAM_NAME} ROOT_PATH SENT_PATH OUTPUT_PATH" unless ARGV.length == 3

  ARGV.map { |value| Pathname.new(value).expand_path }
end

def selected_oms_number(sent_dir)
  numbers = sent_dir.children.select(&:file?).filter_map do |path|
    match = path.basename.to_s.match(MARKER_PATTERN)
    match[1] if match
  end.uniq
  raise "no Mail.dat OMS marker found in #{sent_dir}" if numbers.empty?
  raise "multiple OMS markers found in #{sent_dir}: #{numbers.join(', ')}" if numbers.length > 1

  numbers.first
end

def classified_inputs(dir, selected_number)
  inputs = Hash.new do |hash, oms_number|
    hash[oms_number] = { companion: [], daily_presort: [], moveresults: [] }
  end

  dir.children.select(&:file?).sort.each do |path|
    name = path.basename.to_s

    {
      companion: COMPANION_PATTERN,
      daily_presort: DAILY_PRESORT_PATTERN,
      moveresults: MOVE_RESULTS_PATTERN
    }.each do |type, pattern|
      match = name.match(pattern)
      inputs[match[1]][type] << path if match && match[1] == selected_number
    end
  end

  inputs
end

def validate_single_inputs!(oms_number, inputs)
  %i[daily_presort moveresults].each do |type|
    next unless inputs.fetch(type).length > 1

    names = inputs.fetch(type).map { |path| path.basename.to_s }.join(', ')
    raise "#{oms_number} has multiple #{type.to_s.tr('_', ' ')} files: #{names}"
  end
end

def atomic_write(output_path)
  FileUtils.mkdir_p(output_path.dirname)

  Tempfile.create([".#{output_path.basename}", '.tmp'], output_path.dirname) do |temp|
    temp.binmode
    yield temp
    temp.flush
    temp.fsync
    FileUtils.mv(temp.path, output_path)
  end
end

def without_line_feeds(row)
  row.map { |value| value&.gsub(/\R+/, ' ') }
end

def output_row(row, oms_number, date_inserted)
  [oms_number, date_inserted, *without_line_feeds(row)]
end

def write_companion(output_path, paths, oms_number, date_inserted)
  expected_header = nil

  atomic_write(output_path) do |temp|
    output = CSV.new(temp)

    paths.each do |path|
      CSV.foreach(path, encoding: 'bom|utf-8').with_index do |row, index|
        if index.zero?
          expected_header ||= row
          raise "#{path.basename}: companion header does not match" unless row == expected_header

          output << [*METADATA_HEADER, *without_line_feeds(row)] if output.lineno.zero?
        else
          output << output_row(row, oms_number, date_inserted)
        end
      end
    end
  end
end

def write_utf16_tsv(output_path, input_path, oms_number, date_inserted)
  atomic_write(output_path) do |temp|
    output = CSV.new(temp)
    options = { col_sep: "\t", encoding: 'UTF-16LE:UTF-8' }
    CSV.foreach(input_path, **options).with_index do |row, index|
      converted = if index.zero?
                    [*METADATA_HEADER, *without_line_feeds(row)]
                  else
                    output_row(row, oms_number, date_inserted)
                  end
      output << converted
    end
  end
end

def build_outputs(output_dir, grouped_inputs)
  written = []
  raise 'multiple OMS numbers found; process one print job at a time' if grouped_inputs.length > 1

  grouped_inputs.sort.each do |oms_number, inputs|
    validate_single_inputs!(oms_number, inputs)
    date_inserted = Time.now.utc.iso8601

    unless inputs[:companion].empty?
      path = output_dir.join('companions.csv')
      write_companion(path, inputs[:companion], oms_number, date_inserted)
      written << [path, inputs[:companion]]
    end

    unless inputs[:daily_presort].empty?
      path = output_dir.join('dailypresorts.csv')
      write_utf16_tsv(path, inputs[:daily_presort].first, oms_number, date_inserted)
      written << [path, inputs[:daily_presort]]
    end

    next if inputs[:moveresults].empty?

    path = output_dir.join('moveresults.csv')
    write_utf16_tsv(path, inputs[:moveresults].first, oms_number, date_inserted)
    written << [path, inputs[:moveresults]]
  end

  written
end

def main
  root_dir, sent_dir, output_dir = paths
  raise "root directory not found: #{root_dir}" unless root_dir.directory?
  raise "sent directory not found: #{sent_dir}" unless sent_dir.directory?

  oms_number = selected_oms_number(sent_dir)
  grouped_inputs = classified_inputs(root_dir, oms_number)
  raise "no OMS input files found for #{oms_number} in #{root_dir}" if grouped_inputs.empty?

  OUTPUT_FILES.each { |name| FileUtils.rm_f(output_dir.join(name)) }
  written = build_outputs(output_dir, grouped_inputs)
  written.each do |output, inputs|
    names = inputs.map { |path| path.basename.to_s }.join(', ')
    puts "[OK] #{names} -> #{output}"
  end
end

main if $PROGRAM_NAME == __FILE__
