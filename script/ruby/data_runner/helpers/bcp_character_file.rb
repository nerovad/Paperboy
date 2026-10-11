# frozen_string_literal: true

# bcp character files: UTF-8, no quoting, field U+001F, row U+001E.
# A value that contains either terminator cannot be loaded with bcp -c.
module BcpCharacterFile
  FIELD = "\u001F"
  ROW = "\u001E"
  APPLIED_DIR_NAME = '05_DSL_Applied'
  FIELD_BYTES = "\x1F".b
  ROW_BYTES = "\x1E".b

  class TerminatorError < StandardError; end

  module_function

  def write_row(io, values, dsl:, columns:)
    texts = Array(values).each_with_index.map do |value, index|
      text = value.nil? ? '' : value.to_s
      column = columns[index] || "column #{index + 1}"
      raise TerminatorError, terminator_message(dsl, column) if text.include?(FIELD) || text.include?(ROW)

      text
    end
    io.write(texts.join(FIELD).b)
    io.write(ROW_BYTES)
  end

  def each_row(path)
    File.open(path, 'rb') do |io|
      leftover = +''.b
      while (chunk = io.read(1 << 20))
        leftover << chunk
        parts = leftover.split(ROW_BYTES, -1)
        leftover = parts.pop || +''.b
        parts.each { |part| yield decode_fields(part) }
      end
      yield decode_fields(leftover) unless leftover.empty?
    end
  end

  def header_and_first_row(path)
    header = nil
    first = nil
    each_row(path) do |row|
      if header.nil?
        header = row.map(&:to_s)
      else
        first = row
        break
      end
    end
    [header, first]
  end

  def applied_path?(path)
    path.to_s.split(%r{[\\/]}).include?(APPLIED_DIR_NAME)
  end

  # Applied output is a character file only when the header row ends on the
  # row terminator. A comma-separated file in the same directory starts with
  # a newline, and reading it as one character record drops every data row.
  def character_bytes?(path)
    File.open(path, 'rb') do |io|
      pending = +''.b
      while pending.bytesize < 1_048_576 && (chunk = io.read(8192))
        pending << chunk
        row_at = pending.index(ROW_BYTES)
        newline_at = pending.index("\n".b)
        return true if row_at && (newline_at.nil? || row_at < newline_at)
        return false if newline_at
      end
    end
    false
  end

  def decode_fields(part)
    part.force_encoding(Encoding::UTF_8).scrub.split(FIELD, -1)
  end

  def terminator_message(dsl, column)
    "#{dsl}: column #{column} contains a bcp field or row terminator"
  end
end
