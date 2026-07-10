#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require_relative 'dsl_map'
require_relative '../helpers/etl_header_helpers'
require_relative '../helpers/etl_helpers'
require_relative '../constants/workflow'
require_relative '../constants/workflow_paths'

DSL_ENTRY_DIR = File.join(__dir__, '../..', 'dsl')
SQL_SCHEMA_DIR = WorkflowPaths::SQL_SCHEMA_DIR

DslEntry = Struct.new(:key, :cfg, :path, keyword_init: true)

def dsl_entries
  Dir[File.join(DSL_ENTRY_DIR, '*.rb')].map do |path|
    entry = TOPLEVEL_BINDING.eval(File.read(path), path)
    DslEntry.new(key: entry[0], cfg: entry[1], path: path)
  end
end

def sql_files(argv)
  EtlHelpers.selected_dsl_entries(DSL_MAP, argv).values
            .map { |cfg| File.join(SQL_SCHEMA_DIR, "#{EtlHelpers.base_for(cfg)}.sql") }
end

def create_table_body(sql)
  lines = sql.lines
  start = lines.find_index { |line| line.match?(/\ACREATE\s+TABLE\b/i) }
  return [] if start.nil?

  body = []
  lines[(start + 1)..].each do |line|
    break if line.match?(/\A\)\s*(ON\b|TEXTIMAGE_ON\b|$)/i)

    body << line
  end
  body
end

def sql_columns(sql)
  lines = create_table_body(sql)
  columns = []
  idx = 0

  while idx < lines.length
    line = lines[idx].strip
    idx += 1
    next unless line.start_with?('[')
    next if line.match?(/\ACONSTRAINT\b/i)

    definition = line.dup
    if definition.match?(/\bENCRYPTED\s+WITH\b/i)
      while idx < lines.length && !definition.match?(/\)\s+(?:NOT\s+NULL|NULL)\b/i)
        definition << ' ' << lines[idx].strip
        idx += 1
      end
    end

    column = parse_column_definition(definition)
    columns << column unless column.nil?
  end

  columns
end

def parse_column_definition(definition)
  text = definition.sub(/,\s*\z/, '')
  match = text.match(/\A\[([^\]]+)\]\s+(.+)\z/m)
  return nil unless match

  name = match[1]
  rest = match[2].gsub(/\s+/, ' ').strip
  data_type, nullability, default_value = parse_sql_type_nullability_default(rest)

  {
    name: name,
    data_type: data_type,
    nullability: nullability,
    default_value: default_value
  }
end

def parse_sql_type_nullability_default(rest)
  rest, default_value = split_default(rest)

  if rest.match?(/\bENCRYPTED\s+WITH\b/i)
    data_type = rest.split(/\s+ENCRYPTED\s+WITH\s+/i, 2).first.strip
    nullability = rest[/\)\s+((?:NOT\s+NULL|NULL).*)\z/i, 1] || 'NULL'
    return [ data_type, nullability.strip, default_value ]
  end

  match = rest.match(/\A(.+?)\s+((?:IDENTITY\s*\([^)]+\)\s+)?(?:NOT\s+NULL|NULL).*)\z/i)
  return [ rest, 'NULL', default_value ] if match.nil?

  [ match[1].strip, match[2].strip, default_value ]
end

def split_default(rest)
  match = rest.match(/\A(.+?)\s+DEFAULT\s+(.+)\z/i)
  return [ rest, nil ] if match.nil?

  [ match[1].strip, parse_default_literal(match[2].strip) ]
end

def parse_default_literal(value)
  value = value.sub(/,\s*\z/, '').strip
  return nil if value.casecmp('NULL').zero?

  quoted = value.match(/\A'(.*)'\z/m)
  return quoted[1].gsub("''", "'") unless quoted.nil?

  value
end

def ruby_literal(value)
  return 'nil' if value.nil?

  "'#{value.to_s.gsub('\\', '\\\\\\').gsub("'", "\\\\'")}'"
end

def aligned_header_rows(rows)
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
  lines.concat(aligned_header_rows(rows)) unless rows.empty?
  lines.push('    ]')
  lines.join("\n")
end

def header_block(columns)
  destinations = EtlHeaderHelpers.uniquify(columns.map { |column| EtlHeaderHelpers.rails_header(column[:name]) })
  rows = columns.zip(destinations).map do |column, destination|
    [ destination, destination, column[:data_type], column[:nullability], column[:default_value] ]
  end

  render_header_block(rows)
end

def replace_header_block(source, replacement)
  header_pos = source.index(/header:\s*\[/)
  raise 'missing header block' if header_pos.nil?

  open_pos = source.index('[', header_pos)
  close_pos = matching_bracket_position(source, open_pos)
  raise 'unterminated header block' if close_pos.nil?

  "#{source[0...header_pos]}#{replacement}#{source[(close_pos + 1)..]}"
end

def matching_bracket_position(source, open_pos)
  depth = 0
  quote = nil
  escape = false

  source.each_char.with_index do |char, idx|
    next if idx < open_pos

    if quote
      escape = !escape && char == '\\'
      if char == quote && !escape
        quote = nil
      elsif char != '\\'
        escape = false
      end
      next
    end

    if [ '\'', '"' ].include?(char)
      quote = char
      next
    end

    depth += 1 if char == '['
    if char == ']'
      depth -= 1
      return idx if depth.zero?
    end
  end

  nil
end

if __FILE__ == $PROGRAM_NAME
  puts 'SQL to DSL started.'

  entries_by_base = dsl_entries.to_h do |entry|
    [ EtlHelpers.base_for(entry.cfg), entry ]
  end

  stats = EtlHelpers::RunStats.new

  sql_files(ARGV).each do |path|
    base = File.basename(path, '.sql')
    entry = entries_by_base[base]

    if entry.nil?
      puts "[SKIP] #{File.basename(path)}: no matching DSL entry"
      stats.skip!
      next
    end

    unless File.exist?(path)
      puts "[FAIL] #{File.basename(path)}: missing #{SQL_SCHEMA_DIR}/#{File.basename(path)}"
      stats.fail!
      next
    end

    begin
      columns = sql_columns(File.read(path))
      updated = replace_header_block(File.read(entry.path), header_block(columns))
      File.write(entry.path, updated)
      puts "[OK] #{File.basename(path)} -> dsl/#{File.basename(entry.path)} (#{columns.length} column(s))"
      stats.ok!
    rescue StandardError => e
      puts "[FAIL] #{File.basename(path)}: #{e}"
      stats.fail!
    end
  end

  puts "\n#{stats.summary}"
  puts 'SQL to DSL completed.'
end
