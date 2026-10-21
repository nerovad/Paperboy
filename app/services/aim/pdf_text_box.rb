# frozen_string_literal: true

require 'prawn'

module Aim
  # A text box on an edited PDF page (#182), drawn as the editor shows it:
  # a box at x, y (its top left) w wide and h tall, as fractions of the page
  # as seen; the text wrapped to the box's width in Helvetica, regular or
  # bold, black, red or blue; behind it nothing, white or a yellow highlight;
  # round it a thin border or none. Older boxes without w or h run to the
  # page's right edge and are as tall as their text.
  module PdfTextBox
    LEADING = 1.2
    ASCENT = 0.8
    PAD = 2
    COLORS = { 'black' => [0, 0, 0], 'red' => [0.8, 0.1, 0.1], 'blue' => [0.1, 0.25, 0.75] }.freeze
    BACKGROUNDS = { 'white' => [1, 1, 1], 'yellow' => [1, 0.95, 0.4] }.freeze

    module_function

    # The content for +texts+ on a seen page +width+ by +height+ points, in
    # the seen page's own coordinates (origin bottom left).
    def stream(texts, width, height, fonts)
      texts.map { |text| box(text, width, height, fonts) }.join
    end

    def box(text, width, height, fonts)
      size = text[:size].to_f.clamp(4.0, 72.0)
      bold = ActiveModel::Type::Boolean.new.cast(text[:bold])
      left = fraction(text[:x]) * width
      top = (1 - fraction(text[:y])) * height
      box_width = text[:w].present? ? fraction(text[:w]) * width : width - left
      lines = wrap(text[:text].to_s, box_width - (PAD * 2), size, bold)
      needed = (lines.size * size * LEADING) + (PAD * 2)
      box_height = text[:h].present? ? [fraction(text[:h]) * height, needed].max : needed
      body = +''
      body << fill(BACKGROUNDS[text[:bg].to_s], left, top - box_height, box_width, box_height)
      body << border(left, top - box_height, box_width, box_height) if ActiveModel::Type::Boolean.new.cast(text[:border])
      body << words(lines, left + PAD, top - PAD, size, fonts[bold ? :bold : :regular], COLORS.fetch(text[:color].to_s, COLORS['black']))
    end

    def fill(rgb, x, y, w, h)
      return '' if rgb.nil?

      "q #{rgb.map { |n| number(n) }.join(' ')} rg #{[x, y, w, h].map { |n| number(n) }.join(' ')} re f Q\n"
    end

    def border(x, y, w, h) = "q 0 G 0.75 w #{[x, y, w, h].map { |n| number(n) }.join(' ')} re S Q\n"

    def words(lines, x, top, size, font, rgb)
      body = "BT\n#{rgb.map { |n| number(n) }.join(' ')} rg\n/#{font} #{number(size)} Tf\n"
      lines.each_with_index do |line, index|
        y = top - (size * ASCENT) - (index * size * LEADING)
        body << "1 0 0 1 #{number(x)} #{number(y)} Tm\n#{PdfGeometry.literal(line)} Tj\n"
      end
      body << "ET\n"
    end

    # The text's lines: its own line breaks kept, each wrapped at spaces to
    # +room+ points, a word too long for the box broken where it must.
    def wrap(text, room, size, bold)
      text.split(/\r?\n/, -1).flat_map do |paragraph|
        lines = ['']
        paragraph.split(/(?<= )/).each do |word|
          candidate = lines.last + word
          if lines.last.empty? || measure(candidate.rstrip, size, bold) <= room
            lines[-1] = candidate
          else
            lines << word
          end
          lines.concat(break_word(lines.pop, room, size, bold)) if measure(lines.last.rstrip, size, bold) > room
        end
        lines.map(&:rstrip)
      end
    end

    def break_word(word, room, size, bold)
      word.each_char.with_object(['']) do |char, pieces|
        pieces << '' if !pieces.last.empty? && measure(pieces.last + char, size, bold) > room
        pieces[-1] += char
      end
    end

    def measure(text, size, bold) = metrics(bold).width_of(text, size: size)

    def metrics(bold)
      @metrics ||= {}
      @metrics[bold] ||= Prawn::Document.new.tap { |doc| doc.font('Helvetica', style: bold ? :bold : :normal) }
    end

    def fraction(value) = value.to_f.clamp(0.0, 1.0)

    def number(value) = Paperboy::Pdf::Writer.number(value)
  end
end
