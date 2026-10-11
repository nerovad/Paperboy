#!/usr/bin/env ruby
# frozen_string_literal: true

# {{{ Requirements and definitions.
#     Applies DSL_MAP header DSL (rename / drop / order) to normalized CSVs.

require 'csv'
require 'fileutils'
require 'set'
require_relative 'dsl_map'
require_relative '../helpers/bcp_character_file'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/etl_mapping_helpers'
require_relative '../helpers/sql_value'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(ROOT)

NORMALIZED_DIR = WorkflowPaths::NORMALIZED_DIR
APPLIED_DIR = WorkflowPaths::APPLIED_DIR
FileUtils.mkdir_p(APPLIED_DIR)

def apply_mapping(cfg, input_path, output_path, dsl_name: nil)
  mapping = EtlMappingHelpers.csv_mapping(cfg)
  return :pass if mapping.empty?

  out_cols = mapping.map { |entry| entry[:output] }
  dedup = dedup_enabled?(cfg)
  dsl = dsl_name || File.basename(output_path)

  input_headers = nil
  File.open(input_path, 'r:bom|utf-8') do |io|
    input_headers = CSV.parse_line(io.gets)&.map(&:to_s) || []
  end

  missing_inputs = mapping.filter_map { |entry| entry[:input] }.uniq - input_headers
  puts "  [WARN] mapping references missing input columns: #{missing_inputs.join(', ')}" unless missing_inputs.empty?

  File.open(output_path, 'wb') do |out|
    BcpCharacterFile.write_row(out, out_cols, dsl: dsl, columns: out_cols)

    row_number = 0
    rows = []
    CSV.foreach(input_path, headers: true, encoding: 'bom|utf-8') do |row|
      row_number += 1
      mapped_row = mapped_character_row(mapping, row, row_number, dsl)

      if dedup
        rows << mapped_row
      else
        BcpCharacterFile.write_row(out, mapped_row, dsl: dsl, columns: out_cols)
      end
    end

    write_deduplicated_rows(out, rows, dsl: dsl, columns: out_cols) if dedup
  end

  :applied
end

def write_unmapped_character_file(input_path, output_path, dsl_name)
  headers = nil
  File.open(output_path, 'wb') do |out|
    CSV.foreach(input_path, encoding: 'bom|utf-8') do |row|
      headers ||= row.map(&:to_s)
      BcpCharacterFile.write_row(out, row, dsl: dsl_name, columns: headers)
    end
  end
end

def mapped_character_row(mapping, row, row_number, dsl)
  mapping.map do |entry|
    value = entry[:input].nil? ? nil : row[entry[:input]]
    SqlValue.canonical(EtlMappingHelpers.mapped_value_for(entry, value, row, row_number), entry[:data_type])
  rescue ArgumentError => e
    raise "#{dsl}: column #{entry[:output]}: #{e.message}"
  end
end

def dedup_enabled?(cfg)
  use_dsl = cfg[:use_dsl]
  return false unless use_dsl.is_a?(Hash)

  use_dsl[:dedup] == true
end

def write_deduplicated_rows(io, rows, dsl:, columns:)
  seen = Set.new
  rows.sort_by { |row| CSV.generate_line(row) }.each do |row|
    key = CSV.generate_line(row)
    next unless seen.add?(key)

    BcpCharacterFile.write_row(io, row, dsl: dsl, columns: columns)
  end
end

# -------------------------------------------------------------------------- }}}
# {{{ Main logic

if __FILE__ == $PROGRAM_NAME
  puts 'ApplyHeader started.'

  name_for_output = EtlHelpers.output_name_index(DSL_MAP)

  # ------------------------------------------------------------------------------

  inputs = EtlHelpers.resolve_stage_inputs(ARGV, NORMALIZED_DIR, DSL_MAP)

  # ------------------------------------------------------------------------------

  stats = EtlHelpers::RunStats.new

  inputs.each do |input|
    unless File.exist?(input)
      dsl_name = name_for_output[File.basename(input)]
      dsl_config = dsl_name && DSL_MAP[dsl_name]
      if dsl_config && EtlHelpers.source_strategy(dsl_config) == :append
        puts "[SKIP] #{dsl_name}: nothing to append (missing #{File.basename(input)})"
        stats.skip!
      else
        puts "[SKIP] Missing #{File.basename(input)}"
        stats.fail!
      end
      next
    end

    out_name = File.basename(input)
    map_name = name_for_output[out_name]

    if map_name && !Workflow.wants_step?(DSL_MAP[map_name], :use_dsl)
      puts "[SKIP] #{map_name}: step disabled (:use_dsl)"
      stats.skip!
      next
    end

    base = File.basename(input, '.csv')
    out  = File.join(APPLIED_DIR, "#{base}.csv")

    begin
      cfg = map_name ? DSL_MAP[map_name] : nil
      result = apply_mapping(cfg, input, out, dsl_name: map_name || out_name)

      if result == :pass
        write_unmapped_character_file(input, out, map_name || out_name)
        puts "[PASS] #{out_name} (no mapping) -> #{APPLIED_DIR}/#{File.basename(out)}"
      else
        puts "[OK] #{out_name} -> #{APPLIED_DIR}/#{File.basename(out)}"
      end

      stats.ok!
    rescue StandardError => e
      puts "[FAIL] #{out_name}: #{e}"
      stats.fail!
    end
  end

  # -------------------------------------------------------------------------- }}}
  # {{{ Execution summary

  puts "\n#{stats.summary}"
  puts 'ApplyHeader completed.'
  exit 1 if stats.fail.positive?
end

# -------------------------------------------------------------------------- }}}
