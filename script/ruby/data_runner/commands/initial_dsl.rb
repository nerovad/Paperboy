#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'roo'
require_relative '../helpers/etl_helpers'
require_relative '../helpers/etl_header_helpers'
require_relative '../db/mssql_helpers'
require_relative '../constants/workflow_paths'

DOWNLOAD_DIR = WorkflowPaths::DOWNLOAD_DIR
DSL_DIR = File.expand_path('../../../../dsl', __dir__)

SCAN_LIMIT = 60

def dataset_key_for(file_name)
  base = File.basename(file_name, File.extname(file_name))
  parts = base.split(/[^0-9A-Za-z]+/).reject(&:empty?)
  key = parts.map { |p| p[0].upcase + p[1..].to_s.downcase }.join
  key.empty? ? 'Dataset' : key
end

def to_symbol_format(file_name)
  ext = File.extname(file_name).downcase
  case ext
  when '.xlsx' then :xlsx
  when '.csv' then :csv
  when '.xml' then :xml
  else :unknown
  end
end

def present?(value)
  !value.nil? && value.to_s.strip != ''
end

def score_header_row(rows, idx)
  row = rows[idx] || []
  values = row.map { |c| c.to_s.strip }.reject(&:empty?)
  return -Float::INFINITY if values.length < 2

  next_values = (rows[idx + 1] || []).map { |c| c.to_s.strip }.reject(&:empty?)
  alpha_count = values.count { |v| v.match?(/[A-Za-z]/) }
  uniq_ratio = values.map(&:downcase).uniq.length.to_f / values.length

  values.length + (alpha_count * 0.5) + uniq_ratio + (next_values.empty? ? 0.0 : 0.5)
end

def detect_header_index(rows)
  best_idx = nil
  best_score = -Float::INFINITY

  rows.each_index do |idx|
    score = score_header_row(rows, idx)
    next unless score > best_score

    best_score = score
    best_idx = idx
  end

  best_idx || 0
end

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

def read_csv_rows(path)
  encodings = ['bom|utf-8', 'ISO-8859-1:UTF-8']
  last_error = nil

  encodings.each do |encoding|
    rows = []
    CSV.foreach(path, encoding: encoding).with_index do |row, idx|
      rows << row
      break if idx >= SCAN_LIMIT - 1
    end
    return rows
  rescue StandardError => e
    last_error = e
    raise unless e.message.match?(/invalid byte sequence/i)
  end

  raise last_error if last_error

  []
end

def read_xlsx_rows(path)
  sheet = open_workbook(path).sheet(0)
  last = sheet.last_row || 1
  max = [last, SCAN_LIMIT].min

  (1..max).map { |idx| sheet.row(idx) }
end

def infer_header(file_path, format)
  rows = case format
         when :xlsx then read_xlsx_rows(file_path)
         when :csv then read_csv_rows(file_path)
         else []
         end

  return [0, []] if rows.empty?

  header_idx = detect_header_index(rows)
  raw = rows[header_idx] || []
  raw = raw.take_while { |value| present?(value) }
  cleaned = raw.map { |h| EtlHeaderHelpers.rails_header(h) }
  header = EtlHeaderHelpers.uniquify(cleaned).reject(&:empty?)
  header = ['col_1'] if header.empty?

  [header_idx, header]
end

def default_mssql_host
  MssqlHelpers.load_dotenv!
  host = MssqlHelpers.env_any('MSSQL_HOST', 'GSABSS_HOST').to_s.strip
  return host unless host.empty?

  'MSSQL_HOST'
end

def ruby_literal(value)
  return 'nil' if value.nil?

  "'#{value.to_s.gsub('\\', '\\\\\\').gsub("'", "\\\\'")}'"
end

def render_header_rows(rows)
  literals = rows.map { |row| row.map { |value| ruby_literal(value) } }
  widths = literals.transpose.map { |column| column.map(&:length).max }

  literals.map do |row|
    fields = row.each_with_index.map do |value, index|
      index == row.length - 1 ? value : "#{value},#{' ' * (widths[index] - value.length + 1)}"
    end
    "      [#{fields.join}],"
  end
end

def render_header_block(rows)
  lines = [
    'header: [',
    ''
  ]
  lines.concat(render_header_rows(rows)) unless rows.empty?
  lines.push('    ]')
  lines.join("\n")
end

def render_entry(dataset_key, local_name, format, header_row_idx, header_cols)
  table_name = EtlHeaderHelpers.rails_header(File.basename(local_name, File.extname(local_name)))
  data_row_idx = header_row_idx + 1
  database_host = default_mssql_host
  header_rows = header_cols.map { |column| [column, column, 'nvarchar(max)', 'NULL', nil] }

  <<~RUBY
    # frozen_string_literal: true

    [
      #{ruby_literal(dataset_key)},
      {
        steps: {
          enabled: true,
          manual_steps: Workflow::MANUAL_STEPS,
          scheduled: {
            frequency: :daily,
            steps: Workflow::SCHEDULED_STEPS
          }
        },
        source: {
          location: #{ruby_literal(File.join('/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download', local_name))},
          local: #{ruby_literal(local_name)},
          format: :#{format},
          strategy: :copy
        },
        to_csv: {
          sheet: 0,
          header_row: #{header_row_idx},
          data_row: #{data_row_idx}
        },
        #{render_header_block(header_rows)},
        database_connections: [
          {
            host: #{ruby_literal(database_host)},
            database: 'GSABSS',
            schema: 'dbo',
            table: #{ruby_literal(table_name)},
            inject: {
              mode: :truncate_insert
            }
          }
        ]
      }
    ]
  RUBY
end

puts 'Initial DSL generation started.'

FileUtils.mkdir_p(DOWNLOAD_DIR)
FileUtils.mkdir_p(DSL_DIR)

inputs = Dir[File.join(DOWNLOAD_DIR, '*')].select { |p| File.file?(p) }
targets = inputs.select do |path|
  %w[.xlsx .csv .xml].include?(File.extname(path).downcase)
end

selector = EtlHelpers.single_stage_arg(ARGV)
unless selector.nil?
  wanted = File.basename(selector, File.extname(selector)).downcase
  targets = targets.select do |path|
    File.basename(path, File.extname(path)).downcase == wanted
  end
  abort "unknown inbox source: #{selector}" if targets.empty?
end

stats = EtlHelpers::RunStats.new

puts "[SKIP] No .xlsx, .csv, or .xml files found in #{DOWNLOAD_DIR}" if targets.empty?

targets.sort.each do |input_path|
  file_name = File.basename(input_path)
  format = to_symbol_format(file_name)
  base = File.basename(file_name, File.extname(file_name))
  out_path = File.join(DSL_DIR, "#{base}.rb")

  if File.exist?(out_path)
    puts "[SKIP] #{file_name}: #{File.basename(out_path)} already exists"
    stats.skip!
    next
  end

  begin
    header_row_idx, header_cols = infer_header(input_path, format)
    key = dataset_key_for(file_name)
    content = render_entry(key, file_name, format, header_row_idx, header_cols)

    File.write(out_path, content)
    puts "[OK] #{file_name} -> dsl/#{File.basename(out_path)} (header_row=#{header_row_idx}, cols=#{header_cols.length})"
    stats.ok!
  rescue StandardError => e
    puts "[FAIL] #{file_name}: #{e}"
    stats.fail!
  end
end

puts "\n#{stats.summary}"
puts 'Initial DSL generation completed.'
