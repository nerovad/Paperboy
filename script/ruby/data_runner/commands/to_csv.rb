#!/usr/bin/env ruby
# frozen_string_literal: true

# {{{ Requirements and definitions.
require 'csv'
require 'fileutils'
require 'roo'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/etl_header_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

DOWNLOAD_DIR = WorkflowPaths::DOWNLOAD_DIR
NORMALIZED_DIR = WorkflowPaths::NORMALIZED_DIR
FileUtils.mkdir_p(NORMALIZED_DIR)

# -------------------------------------------------------------------------- }}}
# {{{ Workbook helpers

def open_workbook(path)
  orig_stderr = $stderr
  begin
    $stderr = File.open(File::NULL, 'w')
    Roo::Spreadsheet.open(path)
  ensure
    $stderr.close if $stderr && $stderr != orig_stderr
    $stderr = orig_stderr
  end
end

def value_present?(value)
  !value.nil? && value.to_s.strip != ''
end

def trailing_data_rows(sheet, data_row)
  last = sheet.last_row || data_row
  rows = []

  (data_row..last).each do |row_idx|
    row = sheet.row(row_idx)
    break if row.nil? || row.compact.empty?

    rows << row
  end

  rows
end

def columns_to_keep(raw_header, rows)
  col_count = raw_header.length

  (0...col_count).select do |col_idx|
    has_header = value_present?(raw_header[col_idx])
    has_data = rows.any? { |row| value_present?(row[col_idx]) }
    has_header || has_data
  end
end

def write_csv(path, header, rows)
  railsified_header = EtlHeaderHelpers.uniquify(header.map { |h| EtlHeaderHelpers.rails_header(h) })

  CSV.open(path, 'w') do |out|
    out << railsified_header
    rows.each { |row| out << row }
  end
end

def authoritative_input_header(cfg)
  header = cfg[:header]
  return nil unless header.is_a?(Array)

  names = header.map { |row| row.is_a?(Array) ? row.first.to_s.strip : '' }
  return nil if names.empty? || names.any?(&:empty?)
  return nil if names.uniq.size != names.size

  names
end

def output_csv_path(cfg)
  File.join(NORMALIZED_DIR, EtlHelpers.output_for(cfg))
end

def input_paths(local)
  Array(local).map { |file| File.join(DOWNLOAD_DIR, file) }
end

# -------------------------------------------------------------------------- }}}
# {{{ Process xlsx datasets

def process_xlsx_dataset(name, cfg, stats)
  local = EtlHelpers.source_local(cfg)
  if local.nil? || local.to_s.strip.empty?
    puts "[FAIL] #{name}: missing source.local"
    stats.fail!
    return
  end

  excel_path = File.join(DOWNLOAD_DIR, local)
  csv_path = output_csv_path(cfg)
  output = File.basename(csv_path)

  unless File.exist?(excel_path)
    puts "[SKIP] Missing #{local}"
    stats.skip!
    return
  end

  cnv = cfg[:to_csv] || {}
  sheet_idx = cnv.fetch(:sheet)
  header_row = cnv.fetch(:header_row) + 1
  data_row = cnv.fetch(:data_row) + 1

  sheet = open_workbook(excel_path).sheet(sheet_idx)
  raw_header = sheet.row(header_row)
  raise 'missing header row' if raw_header.nil? || raw_header.compact.empty?

  rows = trailing_data_rows(sheet, data_row)
  keep_cols = columns_to_keep(raw_header, rows)
  header = raw_header.values_at(*keep_cols)
  data = rows.map { |row| row.values_at(*keep_cols) }

  write_csv(csv_path, header, data)
  puts "[OK] #{local} -> #{output}"
  stats.ok!
rescue KeyError => e
  puts "[FAIL] #{name}: missing convert setting: #{e.message}"
  stats.fail!
rescue StandardError => e
  puts "[FAIL] #{local}: #{e}"
  stats.fail!
end

# -------------------------------------------------------------------------- }}}
# {{{ Process csv datasets

def process_csv_dataset(name, cfg, stats)
  local = EtlHelpers.source_local(cfg)
  if local.nil? || local.to_s.strip.empty?
    puts "[FAIL] #{name}: missing source.local"
    stats.fail!
    return
  end

  input = File.join(DOWNLOAD_DIR, local)
  output = output_csv_path(cfg)

  unless File.exist?(input)
    puts "[SKIP] Missing #{local}"
    stats.skip!
    return
  end

  EtlHeaderHelpers.cleanup_one(input, output, authoritative_header: authoritative_input_header(cfg))
  puts "[OK] #{local} -> #{File.basename(output)}"
  stats.ok!
rescue StandardError => e
  puts "[FAIL] #{local}: #{e}"
  stats.fail!
end

# -------------------------------------------------------------------------- }}}
# {{{ Process dataset dispatcher

def process_dataset(name, cfg, stats)
  unless Workflow.wants_step?(cfg, :to_csv)
    puts "[SKIP] #{name}: step disabled (:to_csv)"
    stats.skip!
    return
  end

  case EtlHelpers.source_format(cfg)
  when :xlsx
    process_xlsx_dataset(name, cfg, stats)
  when :csv
    process_csv_dataset(name, cfg, stats)
  else
    puts "[FAIL] #{name}: unsupported source.format #{EtlHelpers.source_format(cfg).inspect}"
    stats.fail!
  end
end

# -------------------------------------------------------------------------- }}}
# {{{ Main logic

puts 'To CSV started.'

stats = EtlHelpers::RunStats.new
EtlHelpers.selected_dsl_entries(DSL_MAP, ARGV).each { |name, cfg| process_dataset(name, cfg, stats) }

puts "\nTo CSV: #{stats.summary}"
puts 'To CSV completed.'

# -------------------------------------------------------------------------- }}}
