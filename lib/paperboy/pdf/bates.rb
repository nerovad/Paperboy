# frozen_string_literal: true

module Paperboy
  module Pdf
    # Bates numbering: a prefix and a running number, zero-padded to +digits+,
    # one per stamped page -- GSA-000123, GSA-000124 ... -- starting at
    # +start+. The engine only numbers; where the next number is kept is the
    # caller's (a counter row of its own).
    #
    # The per-page fields a stamp area can use beside any others:
    #   {number}        the number, zero-padded (with the prefix, if any): 000123
    #   {bates}         the same, by its usual name
    #   {bates_number}  the number alone, unpadded: 123
    #   {page} {pages}  this page and the document's page count
    # A prefix can also be plain text in the row: "GSA-{number}".
    Bates = Data.define(:prefix, :digits, :start) do
      # "000123" as a start: six digits, from 123 -- the zeros set the width.
      def self.from_start(text, prefix: '')
        digits = text.to_s.strip[/\A\d+\z/]&.length || 1
        build(prefix: prefix, digits: digits, start: text.to_s.to_i)
      end

      def self.build(prefix:, digits:, start:)
        new(prefix: prefix.to_s.strip, digits: digits.to_i.clamp(1, 12), start: [start.to_i, 0].max)
      end

      def label(number) = "#{prefix}#{number.to_s.rjust(digits, '0')}"

      # The fields for page +page+ (from 1) of +pages+, numbered +number+.
      # Text, so a number is never shown as money.
      def page_values(number, page, pages)
        { 'number' => label(number), 'bates' => label(number), 'bates_number' => number.to_s, 'page' => page.to_s,
          'pages' => pages.to_s }
      end
    end
  end
end
