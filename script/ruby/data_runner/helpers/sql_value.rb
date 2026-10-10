# frozen_string_literal: true

require 'bigdecimal'
require 'date'
require 'time'

# Canonical text for a bcp character field. Blank numbers and times become
# empty, which the staging insert stores as NULL. Strings keep an empty field.
module SqlValue
  module_function

  def canonical(value, data_type = nil)
    return '' if value.nil?

    text = cell_text(value)
    return '' if blank_becomes_null?(data_type) && text.strip.empty?
    return canonical_numeric(text, data_type) if numeric?(data_type)
    return canonical_temporal(text, data_type) if temporal?(data_type)

    text
  end

  # TinyTDS returns Time, Date, BigDecimal, and true/false. Time#to_s carries a
  # zone and BigDecimal#to_s can be scientific, so the file gets a plain literal.
  def cell_text(value)
    case value
    when nil then nil
    when Time then format_time(value, '%Y-%m-%d %H:%M:%S')
    when Date then value.strftime('%Y-%m-%d')
    when BigDecimal then value.to_s('F')
    when Float then float_text(value)
    when true, false then value ? 'true' : 'false'
    else value.to_s
    end
  end

  def float_text(value)
    text = value.to_s
    return text unless text.match?(/e/i)

    BigDecimal(text).to_s('F')
  end

  def blank_becomes_null?(data_type)
    numeric?(data_type) || temporal?(data_type)
  end

  def numeric?(data_type)
    %w[bigint bit decimal float int money numeric real smallint smallmoney tinyint].include?(type_name(data_type))
  end

  def temporal?(data_type)
    %w[date datetime datetime2 smalldatetime datetimeoffset time].include?(type_name(data_type))
  end

  def type_name(data_type)
    data_type.to_s.strip.downcase[/\A\[?([^\](\s]+)/, 1]
  end

  def canonical_numeric(text, data_type)
    normalized = normalized_numeric_text(text.strip)
    if integer_type?(data_type)
      Integer(normalized, 10).to_s
    elsif type_name(data_type) == 'bit'
      bit_text(normalized)
    else
      BigDecimal(normalized).to_s('F')
    end
  rescue ArgumentError
    raise ArgumentError, "invalid #{data_type} value #{text.strip.inspect}"
  end

  def normalized_numeric_text(text)
    normalized = text.tr(',', '')
    negative = normalized.start_with?('(') && normalized.end_with?(')')
    normalized = normalized[1...-1] if negative
    negative ||= normalized.start_with?('-')
    normalized = normalized.delete_prefix('-').delete_prefix('$')
    negative ? "-#{normalized}" : normalized
  end

  def integer_type?(data_type)
    %w[bigint int smallint tinyint].include?(type_name(data_type))
  end

  def bit_text(value)
    case value.downcase
    when '1', 'true', 't', 'yes', 'y' then '1'
    when '0', 'false', 'f', 'no', 'n' then '0'
    else
      integer = Integer(value, 10)
      raise ArgumentError, 'bit value must be 0 or 1' unless [0, 1].include?(integer)

      integer.to_s
    end
  end

  def canonical_temporal(text, data_type)
    stripped = text.strip
    case type_name(data_type)
    when 'date'
      parse_date(stripped).strftime('%Y-%m-%d')
    when 'time'
      format_time(parse_time(stripped), '%H:%M:%S')
    else
      format_time(parse_datetime(stripped), '%Y-%m-%d %H:%M:%S')
    end
  end

  def parse_date(text)
    case text
    when %r{\A\d{1,2}/\d{1,2}/\d{4}\z} then Date.strptime(text, '%m/%d/%Y')
    when %r{\A\d{1,2}/\d{1,2}/\d{2}\z} then Date.strptime(text, '%m/%d/%y')
    when /\A\d{4}-\d{1,2}-\d{1,2}\z/ then Date.strptime(text, '%Y-%m-%d')
    else Date.parse(text)
    end
  end

  def parse_datetime(text)
    case text
    when %r{\A\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}(?::\d{2})? [AP]M\z}i
      Time.strptime(text, text.count(':') == 1 ? '%m/%d/%Y %I:%M %p' : '%m/%d/%Y %I:%M:%S %p')
    when %r{\A\d{1,2}/\d{1,2}/\d{2} \d{1,2}:\d{2}(?::\d{2})? [AP]M\z}i
      Time.strptime(text, text.count(':') == 1 ? '%m/%d/%y %I:%M %p' : '%m/%d/%y %I:%M:%S %p')
    else
      Time.parse(text)
    end
  end

  def parse_time(text)
    case text
    when /\A\d{1,2}:\d{2}(?::\d{2})? [AP]M\z/i
      Time.strptime(text, text.count(':') == 1 ? '%I:%M %p' : '%I:%M:%S %p')
    else
      Time.parse(text)
    end
  end

  def format_time(time, base_format)
    fraction = time.nsec.zero? ? '' : ".#{time.nsec.to_s.rjust(9, '0')[0, 7].sub(/0+\z/, '')}"
    "#{time.strftime(base_format)}#{fraction}"
  end
end
