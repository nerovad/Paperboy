# frozen_string_literal: true

require 'csv'

# Shared header helper methods for ETL stage scripts.
module EtlHeaderHelpers
  module_function

  def rails_header(name)
    s = name.to_s.strip.downcase
    s.gsub!(/\s+/, '_')
    s.gsub!(/[^a-z0-9_]/, '')
    s.gsub!(/_+/, '_')
    s.gsub!(/^_+|_+$/, '')

    s = 'col' if s.empty?
    s = "col_#{s}" if s.match?(/\A\d/)
    s
  end

  def uniquify(list, blank: 'col')
    seen = Hash.new(0)

    list.map do |name|
      base = name.to_s
      base = blank if base.empty?

      seen[base] += 1
      seen[base] == 1 ? base : "#{base}_#{seen[base]}"
    end
  end

  def cleanup_one(input_path, output_path, authoritative_header: nil)
    encodings = [ 'bom|utf-8', 'ISO-8859-1:UTF-8' ]
    last_error = nil

    cleaned = encodings.any? do |encoding|
      File.open(input_path, "r:#{encoding}") do |in_io|
        header_raw = CSV.parse_line(in_io.gets)
        raise 'missing header row' if header_raw.nil? || header_raw.empty?

        header =
          if authoritative_header&.size == header_raw.size
            authoritative_header
          else
            uniquify(header_raw.map { |h| rails_header(h) })
          end

        CSV.open(output_path, 'w') do |out|
          out << header
          CSV.new(in_io).each { |row| out << row }
        end
      end
      true
    rescue StandardError => e
      last_error = e
      raise unless e.message.match?(/invalid byte sequence/i)

      false
    end

    raise last_error if !cleaned && last_error
  end
end
