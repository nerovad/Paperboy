# frozen_string_literal: true

module Paperboy
  module Pdf
    # The page content that draws one placed stamp area: its background (see-
    # through through the graphics state +state+ when it has one), its border,
    # and its lines in the font resource +font+, each aligned in the box.
    module StampDrawing
      module_function

      # A turned area is drawn unturned about the origin, then turned and
      # moved to its centre: clockwise as seen, so the angle is negative.
      def draw(box, placed, font:, state: nil)
        return area(box, placed, font, state) if placed.rotation.zero?

        centre_x, centre_y = placed.centre
        radians = -placed.rotation * Math::PI / 180
        turn = [Math.cos(radians), Math.sin(radians), -Math.sin(radians), Math.cos(radians), centre_x, centre_y]
        "q\n#{turn.map { |n| number(n) }.join(' ')} cm\n" \
          "#{area(box, placed.with(left: placed.left - centre_x, bottom: placed.bottom - centre_y), font, state)}Q\n"
      end

      def area(box, placed, font, state)
        body = +''
        if box.background && box.opacity.positive?
          body << "q\n"
          body << "/#{state} gs\n" if state
          body << "#{rgb(box.background)} rg\n#{rect(placed)} re f\nQ\n"
        end
        body << "q\n#{rgb(box.color)} RG\n0.5 w\n#{rect(placed)} re S\nQ\n" if box.border
        body << "q\n#{rgb(box.color)} rg\nBT\n/#{font} #{number(placed.size)} Tf\n"
        baseline = placed.top - StampBox::PAD - (placed.size * Fonts::ASCENT)
        placed.lines.each_with_index do |line, index|
          y = baseline - (index * box.line_height(placed.size))
          body << "1 0 0 1 #{number(line_x(box, placed, line))} #{number(y)} Tm\n#{literal(line)} Tj\n"
        end
        body << "ET\nQ\n"
      end

      def line_x(box, placed, line)
        inner = placed.width - (StampBox::PAD * 2)
        used = box.text_width(line, placed.size)
        offset = case box.align
                 when 'right' then inner - used
                 when 'center' then (inner - used) / 2
                 else 0
                 end
        placed.left + StampBox::PAD + offset
      end

      def rect(placed) = [placed.left, placed.bottom, placed.width, placed.height].map { |n| number(n) }.join(' ')

      def rgb(hex) = hex.delete('#').scan(/../).map { |pair| number(pair.to_i(16) / 255.0) }.join(' ')

      def number(value) = Writer.number(value)

      # A PDF string in WinAnsi; a character outside it prints as "?".
      def literal(text)
        bytes = text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?').b
        "(#{bytes.gsub(/[\\()]/) { |char| "\\#{char}" }})"
      end
    end
  end
end
