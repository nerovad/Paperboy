#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'pathname'
require 'tempfile'

# Assemble the files exported by OMS into one consistently named set per
# eight-digit OMS number.
#
# Usage:
#   ruby script/ruby/data_runner/download/oms.rb SOURCE_DIR [MAIL_DAT]
#
# Generated files are written to SOURCE_DIR/Output:
#   NNNNNNNN_companion.csv
#   NNNNNNNN_daily_presort.csv
#   NNNNNNNN_moveresults.csv
# With MAIL_DAT, NNNNNNNN_mail_dat.zip is also copied.
#
# Companion inputs have names like NNNNNNNN-...-.csv. Their common header is
# written once and their data rows are appended in filename order.
# MoveResults_NNNNNNNN.txt is treated as UTF-16LE tab-delimited text and
# serialized as standards-compliant CSV. Mail.dat_NNNNNNNN.zip is copied
# without modifying
# its contents.
OUTPUT_DIR_NAME = 'Output'
OMS_NUMBER_PATTERN = '\d{8}'
COMPANION_PATTERN = /\A(#{OMS_NUMBER_PATTERN})-.+\.csv\z/i
MAIL_DATA_PATTERN = /\AMail\.dat(?:a)?_(#{OMS_NUMBER_PATTERN})\.zip\z/i
MOVE_RESULTS_PATTERN = /\AMoveResults_(#{OMS_NUMBER_PATTERN})\.txt\z/i
DAILY_PRESORT_PATTERN = /\APresort Fields Export_(#{OMS_NUMBER_PATTERN})\.txt\z/i

def source_dir
  valid_args = ARGV.length == 1 || (ARGV.length == 2 && ARGV[1].casecmp?('MAIL_DAT'))
  raise "usage: #{$PROGRAM_NAME} SOURCE_DIR [MAIL_DAT]" unless valid_args

  Pathname.new(ARGV.fetch(0)).expand_path
end

def include_mail_dat?
  ARGV.length == 2
end

def classified_inputs(dir)
  inputs = Hash.new do |hash, oms_number|
    hash[oms_number] = { companion: [], daily_presort: [], mail_data: [], moveresults: [] }
  end

  dir.children.select(&:file?).sort.each do |path|
    name = path.basename.to_s

    {
      companion: COMPANION_PATTERN,
      daily_presort: DAILY_PRESORT_PATTERN,
      mail_data: MAIL_DATA_PATTERN,
      moveresults: MOVE_RESULTS_PATTERN
    }.each do |type, pattern|
      match = name.match(pattern)
      inputs[match[1]][type] << path if match
    end
  end

  inputs
end

def validate_single_inputs!(oms_number, inputs)
  %i[daily_presort mail_data moveresults].each do |type|
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

def write_companion(output_path, paths)
  expected_header = nil

  atomic_write(output_path) do |temp|
    output = CSV.new(temp)

    paths.each do |path|
      CSV.foreach(path, encoding: 'bom|utf-8').with_index do |row, index|
        if index.zero?
          expected_header ||= row
          raise "#{path.basename}: companion header does not match" unless row == expected_header

          output << without_line_feeds(row) if output.lineno.zero?
        else
          output << without_line_feeds(row)
        end
      end
    end
  end
end

def write_utf16_tsv(output_path, input_path)
  atomic_write(output_path) do |temp|
    output = CSV.new(temp)
    options = { col_sep: "\t", encoding: 'UTF-16LE:UTF-8' }
    CSV.foreach(input_path, **options) { |row| output << without_line_feeds(row) }
  end
end

def copy_mail_data(output_path, input_path)
  atomic_write(output_path) do |temp|
    File.open(input_path, 'rb') { |input| IO.copy_stream(input, temp) }
  end
end

def build_outputs(dir, grouped_inputs, include_mail_dat: false)
  output_dir = dir.join(OUTPUT_DIR_NAME)
  written = []

  grouped_inputs.sort.each do |oms_number, inputs|
    validate_single_inputs!(oms_number, inputs)

    unless inputs[:companion].empty?
      path = output_dir.join("#{oms_number}_companion.csv")
      write_companion(path, inputs[:companion])
      written << [path, inputs[:companion]]
    end

    unless inputs[:daily_presort].empty?
      path = output_dir.join("#{oms_number}_daily_presort.csv")
      write_utf16_tsv(path, inputs[:daily_presort].first)
      written << [path, inputs[:daily_presort]]
    end

    if include_mail_dat && !inputs[:mail_data].empty?
      path = output_dir.join("#{oms_number}_mail_dat.zip")
      copy_mail_data(path, inputs[:mail_data].first)
      written << [path, inputs[:mail_data]]
    end

    next if inputs[:moveresults].empty?

    path = output_dir.join("#{oms_number}_moveresults.csv")
    write_utf16_tsv(path, inputs[:moveresults].first)
    written << [path, inputs[:moveresults]]
  end

  written
end

def main
  dir = source_dir
  raise "source directory not found: #{dir}" unless dir.directory?

  grouped_inputs = classified_inputs(dir)
  raise "no OMS input files found in #{dir}" if grouped_inputs.empty?

  written = build_outputs(dir, grouped_inputs, include_mail_dat: include_mail_dat?)
  written.each do |output, inputs|
    names = inputs.map { |path| path.basename.to_s }.join(', ')
    puts "[OK] #{names} -> #{output}"
  end
end

main if $PROGRAM_NAME == __FILE__
