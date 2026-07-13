# frozen_string_literal: true

require_relative 'etl_helpers'

# Shared DSL header mapping helpers for SQL generation and CSV application.
module EtlMappingHelpers
  module_function

  def parse_header_row(row, idx)
    unless row.is_a?(Array) && [2, 4, 5].include?(row.size)
      raise "invalid header row at index #{idx} (expected [input, output], [input, output, data_type, nullability], or [input, output, data_type, nullability, default_value])"
    end

    input, output, data_type, nullability, default_value = row
    normalized_type = data_type.to_s.strip
    normalized_nullability = nullability.to_s.strip.upcase

    {
      input: input,
      output: output,
      data_type: normalized_type.empty? ? 'nvarchar(max)' : normalized_type,
      nullability: normalized_nullability.empty? ? 'NULL' : normalized_nullability,
      default_value: default_value
    }
  end

  def header_entries(cfg)
    mapping = cfg[:header]
    return [] if mapping.nil?

    raise 'invalid header mapping (expected: header: [[input, output, data_type, nullability, default_value], ...])' unless mapping.is_a?(Array)

    mapping.each_with_index.map do |row, idx|
      parse_header_row(row, idx)
    rescue StandardError => e
      raise "header mapping parse error at index #{idx}: #{e}"
    end
  end

  def output_columns(cfg)
    cols = header_entries(cfg).filter_map do |entry|
      output = EtlHelpers.normalized_output_name(entry[:output])
      next if output.empty?

      {
        name: output,
        data_type: entry[:data_type],
        nullability: entry[:nullability],
        default_value: entry[:default_value]
      }
    end

    validate_unique!(cols.map { |col| col[:name] }, 'duplicate output column names')
    cols
  end

  def identity_column?(entry)
    entry[:nullability].to_s.match?(/\bIDENTITY\s*\(/i)
  end

  def csv_mapping(cfg)
    return [] unless cfg.is_a?(Hash)

    mapping = header_entries(cfg).filter_map do |entry|
      output = EtlHelpers.normalized_output_name(entry[:output])
      next if output.empty?

      input = entry[:input].to_s.strip
      {
        input: input.empty? ? nil : input,
        output: output,
        identity: identity_column?(entry),
        default_value: entry[:default_value]
      }
    end

    validate_unique!(mapping.map { |entry| entry[:output] }, 'duplicate output column names')
    mapping
  end

  def validate_unique!(values, message)
    dupes = values.group_by(&:itself).select { |_key, entries| entries.size > 1 }.keys
    raise "#{message}: #{dupes.join(', ')}" unless dupes.empty?
  end
end
