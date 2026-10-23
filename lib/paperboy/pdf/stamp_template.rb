# frozen_string_literal: true

module Paperboy
  module Pdf
    # One row of stamp text with fields in it: "{received|%m/%d/%Y}- Invoice
    # Date:{invoice_date|%Y%m%d}". A field is {name}, or {name|format}:
    #
    # * a date or time takes a strftime format;
    # * a number takes "money" ($1,234.50, the default) or "plain" (1234.50);
    # * text takes "upper" or "lower", or nothing;
    # * a number written as text (a Bates number) takes zeros, "000000", to be
    #   padded to that many digits: {number|000000} gives 000123.
    #
    # A separator in square brackets just before a field -- "[ _ ]{program}"
    # -- prints only when that field has a value, so a row of optional
    # fields joined by separators never shows a separator with nothing after
    # it. Brackets not followed by a field are plain text.
    #
    # A field with no value prints as +blank+. A row whose fields are all
    # empty is left out (#skip?), so a row that only applies sometimes -- a
    # second approval -- needs no condition of its own. A row of plain text
    # always prints.
    class StampTemplate
      TOKEN = /(?:\[([^\[\]{}]*)\])?\{([a-z][a-z0-9_]*)(?:\|([^{}]*))?\}/

      Row = Data.define(:text, :fields, :filled) do
        def skip? = fields.any? && filled.zero?
      end

      def self.fields(text) = text.to_s.scan(TOKEN).map(&:second)

      # +values+: { 'name' => value }; +formats+: { 'name' => default format }.
      def initialize(values, formats: {}, blank: '')
        @values = values.transform_keys(&:to_s)
        @formats = formats.transform_keys(&:to_s)
        @blank = blank.to_s
      end

      def fill(text)
        fields = []
        filled = 0
        out = text.to_s.gsub(TOKEN) do
          separator, name, style = Regexp.last_match.captures
          fields << name
          shown = render(@values[name], style.presence || @formats[name])
          filled += 1 if shown.present?
          if separator then shown.present? ? "#{separator}#{shown}" : ''
          else shown.presence || @blank
          end
        end
        Row.new(text: out, fields: fields, filled: filled)
      end

      # The rows still printed, as text.
      def lines(rows) = rows.map { |row| fill(row) }.reject(&:skip?).map(&:text)

      private

      def render(value, style)
        case value
        when nil, '' then ''
        when Date, Time, DateTime, ActiveSupport::TimeWithZone then value.strftime(style.presence || '%m/%d/%Y')
        when Numeric then number(value, style)
        else text(value.to_s, style)
        end
      end

      def number(value, style)
        return format('%.2f', value) if style == 'plain'

        amount = ActiveSupport::NumberHelper.number_to_currency(value.abs)
        value.negative? ? "-#{amount}" : amount
      end

      def text(value, style)
        return value.to_i.to_s.rjust(style.length, '0') if style.to_s.match?(/\A0+\z/) && value.match?(/\A\d+\z/)

        case style
        when 'upper' then value.upcase
        when 'lower' then value.downcase
        else value
        end
      end
    end
  end
end
