#!/usr/bin/env ruby
# frozen_string_literal: true

# {{{ Requirements and definitions.
#     Applies DSL_MAP header DSL (rename / drop / order) to normalized CSVs.

require 'csv'
require 'fileutils'
require 'set'
require_relative 'dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/etl_mapping_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(ROOT)

NORMALIZED_DIR = WorkflowPaths::NORMALIZED_DIR
APPLIED_DIR = WorkflowPaths::APPLIED_DIR
FileUtils.mkdir_p(APPLIED_DIR)

def apply_mapping(cfg, input_path, output_path)
  mapping = EtlMappingHelpers.csv_mapping(cfg)
  return :pass if mapping.empty?

  out_cols = mapping.map { |entry| entry[:output] }
  dedup = dedup_enabled?(cfg)

  input_headers = nil
  File.open(input_path, 'r:bom|utf-8') do |io|
    input_headers = CSV.parse_line(io.gets)&.map(&:to_s) || []
  end

  missing_inputs = mapping.filter_map { |entry| entry[:input] }.uniq - input_headers
  puts "  [WARN] mapping references missing input columns: #{missing_inputs.join(', ')}" unless missing_inputs.empty?

  CSV.open(output_path, 'w') do |out|
    out << out_cols

    row_number = 0
    rows = []
    CSV.foreach(input_path, headers: true, encoding: 'bom|utf-8') do |row|
      row_number += 1
      mapped_row = mapping.map do |entry|
        value = entry[:input].nil? ? nil : row[entry[:input]]
        mapped_value_for(entry, value, row, row_number)
      end

      if dedup
        rows << mapped_row
      else
        out << mapped_row
      end
    end

    write_deduplicated_rows(out, rows) if dedup
  end

  :applied
end

def dedup_enabled?(cfg)
  use_dsl = cfg[:use_dsl]
  return false unless use_dsl.is_a?(Hash)

  use_dsl[:dedup] == true
end

def write_deduplicated_rows(out, rows)
  seen = Set.new
  rows.sort_by { |row| CSV.generate_line(row) }.each do |row|
    key = CSV.generate_line(row)
    next unless seen.add?(key)

    out << row
  end
end

def mapped_value_for(entry, value, row, row_number)
  return default_value_for(entry[:default_value], row) if value.to_s.empty? && !entry[:default_value].nil?
  return row_number if value.to_s.empty? && entry[:identity]

  value
end

def default_value_for(default_value, row)
  return default_value.call(row) if default_value.respond_to?(:call)

  default_value
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
      puts "[SKIP] Missing #{File.basename(input)}"
      stats.fail!
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
      result = apply_mapping(cfg, input, out)

      if result == :pass
        FileUtils.cp(input, out)
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
end

# -------------------------------------------------------------------------- }}}
