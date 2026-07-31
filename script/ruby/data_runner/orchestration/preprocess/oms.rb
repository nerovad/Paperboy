#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'pathname'
require 'tempfile'
require 'time'

# Assemble the files exported by OMS into one consistently named set per
# eight-digit OMS number.
#
# Usage:
#   ruby script/ruby/data_runner/orchestration/preprocess/oms.rb SOURCE_DIR
#
# Generated files are written to SOURCE_DIR/Output:
#   companions.csv
#   dailypresorts.csv
#   moveresults.csv
#
# Companion inputs have names like NNNNNNNN-...-.csv. Their common header is
# written once and their data rows are appended in filename order.
# MoveResults_NNNNNNNN.txt is treated as UTF-16LE tab-delimited text and
# serialized as standards-compliant CSV.
OUTPUT_DIR_NAME = 'Output'
OMS_NUMBER_PATTERN = '\d{8}'
COMPANION_PATTERN = /\A(#{OMS_NUMBER_PATTERN})-.+\.csv\z/i
MOVE_RESULTS_PATTERN = /\AMoveResults_(#{OMS_NUMBER_PATTERN})\.txt\z/i
DAILY_PRESORT_PATTERN = /\APresort Fields Export_(#{OMS_NUMBER_PATTERN})\.txt\z/i
METADATA_HEADER = %w[omsnumber importdatetime].freeze

def source_dir
  raise "usage: #{$PROGRAM_NAME} SOURCE_DIR" unless ARGV.length == 1

  Pathname.new(ARGV.fetch(0)).expand_path
end

def classified_inputs(dir)
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
      inputs[match[1]][type] << path if match
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

def build_outputs(dir, grouped_inputs)
  output_dir = dir.join(OUTPUT_DIR_NAME)
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
  dir = source_dir
  raise "source directory not found: #{dir}" unless dir.directory?

  grouped_inputs = classified_inputs(dir)
  raise "no OMS input files found in #{dir}" if grouped_inputs.empty?

  written = build_outputs(dir, grouped_inputs)
  written.each do |output, inputs|
    names = inputs.map { |path| path.basename.to_s }.join(', ')
    puts "[OK] #{names} -> #{output}"
  end
end

main if $PROGRAM_NAME == __FILE__
