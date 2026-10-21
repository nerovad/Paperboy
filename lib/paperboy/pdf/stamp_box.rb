# frozen_string_literal: true

module Paperboy
  module Pdf
    # One stamp area: its lines of text, where it sits and how it looks.
    #
    # Where: an anchor -- a corner, an edge's middle, or the centre -- and an
    # offset in points from it, measured inward (x from the left or right
    # edge, y from the top or bottom; from the centre line for a centred
    # anchor). Kept by its anchor, a stamp put bottom right stays bottom right
    # on letter, legal, landscape and turned pages alike. The box grows away
    # from its anchor: a bottom-right stamp grows up and to the left, into
    # the page.
    #
    # Width: nil fits the longest line; a number wraps the text to it.
    #
    # Safety nets, in order (#place): the text wraps to the box, the box is
    # pushed back inside the page's margin, a box taller than the page shrinks
    # its font down to MIN_SIZE, and if it still does not fit it is stamped at
    # MIN_SIZE from the margin anyway. Text is never cut off. Each step taken
    # is a warning.
    StampBox = Data.define(:lines, :anchor, :x, :y, :width, :align, :font, :bold, :italic, :size, :color,
                           :leading, :background, :opacity, :border, :pages)

    class StampBox
      ANCHORS = %w[top_left top_center top_right middle_left center middle_right
                   bottom_left bottom_center bottom_right].freeze
      ALIGNS = %w[left center right].freeze
      PAGES = %w[all first last].freeze
      PAD = 2
      MARGIN = 4
      MIN_SIZE = 6.0
      MAX_SIZE = 36.0
      DEFAULTS = {
        lines: [], anchor: 'bottom_right', x: 8.0, y: 8.0, width: nil, align: 'right', font: 'helvetica',
        bold: false, italic: false, size: 7.0, color: '#000000', leading: 8.5 / 7, background: '#ffffff',
        opacity: 1.0, border: false, pages: 'all'
      }.freeze

      # Where a box landed, and its lines as wrapped there.
      Placement = Data.define(:left, :bottom, :width, :height, :size, :lines, :warnings) do
        def top = bottom + height
      end

      # A box from stored settings, every value checked and held to its range.
      def self.build(attributes)
        given = DEFAULTS.merge(attributes.to_h.transform_keys(&:to_sym).slice(*DEFAULTS.keys).compact)
        new(
          lines: Array(given[:lines]).map(&:to_s),
          anchor: ANCHORS.include?(given[:anchor].to_s) ? given[:anchor].to_s : DEFAULTS[:anchor],
          x: given[:x].to_f.clamp(-2000.0, 2000.0), y: given[:y].to_f.clamp(-2000.0, 2000.0),
          width: given[:width].presence && given[:width].to_f.clamp(20.0, 2000.0),
          align: ALIGNS.include?(given[:align].to_s) ? given[:align].to_s : DEFAULTS[:align],
          font: Fonts.family(given[:font]), bold: truthy(given[:bold]), italic: truthy(given[:italic]),
          size: given[:size].to_f.clamp(MIN_SIZE, MAX_SIZE), color: colour(given[:color]) || '#000000',
          leading: given[:leading].to_f.clamp(1.0, 3.0), background: colour(given[:background]),
          opacity: given[:opacity].to_f.clamp(0.0, 1.0), border: truthy(given[:border]),
          pages: PAGES.include?(given[:pages].to_s) ? given[:pages].to_s : DEFAULTS[:pages]
        )
      end

      def self.truthy(value) = ActiveModel::Type::Boolean.new.cast(value) || false

      def self.colour(value) = value.to_s.downcase[/\A#\h{6}\z/]

      def on_page?(index, count)
        case pages
        when 'first' then index.zero?
        when 'last' then index == count - 1
        else true
        end
      end

      def line_height(at = size) = at * leading

      def text_width(text, at = size) = Fonts.width(text, at, name: font, bold: bold, italic: italic)

      # Where the box lands on a page +page_width+ by +page_height+ points (the
      # page as seen), and the lines as wrapped.
      def place(page_width, page_height)
        warnings = []
        room_width = page_width - (MARGIN * 2)
        room_height = page_height - (MARGIN * 2)
        at = size
        loop do
          wrapped, inner = wrap(at, room_width)
          height = (wrapped.size * line_height(at)) + (PAD * 2)
          if height <= room_height || at <= MIN_SIZE
            warnings << :shrunk if at < size
            warnings << :too_big if height > room_height
            left, bottom = anchored(page_width, page_height, inner + (PAD * 2), height)
            kept_left = keep_inside(left, page_width, inner + (PAD * 2))
            kept_bottom = keep_inside(bottom, page_height, height)
            warnings << :moved_inside if (kept_left - left).abs > 0.01 || (kept_bottom - bottom).abs > 0.01
            return Placement.new(left: kept_left, bottom: kept_bottom, width: inner + (PAD * 2), height: height,
                                 size: at, lines: wrapped, warnings: warnings)
          end
          at = [at - 0.5, MIN_SIZE].max
        end
      end

      private

      # The lines wrapped to the box at size +at+, and the width they take.
      def wrap(at, room_width)
        limit = [width || Float::INFINITY, room_width].min - (PAD * 2)
        wrapped = lines.flat_map { |line| TextWrap.lines(line, limit) { |text| text_width(text, at) } }
        inner = width ? limit : wrapped.map { |line| text_width(line, at) }.max.to_f
        [wrapped, [inner, limit].min]
      end

      def anchored(page_width, page_height, box_width, box_height)
        vertical, horizontal = anchor == 'center' ? %w[middle center] : anchor.split('_')
        left = case horizontal
               when 'left' then x
               when 'right' then page_width - x - box_width
               else ((page_width - box_width) / 2) + x
               end
        bottom = case vertical
                 when 'bottom' then y
                 when 'top' then page_height - y - box_height
                 else ((page_height - box_height) / 2) + y
                 end
        [left, bottom]
      end

      def keep_inside(start, extent, size_of)
        return MARGIN if size_of > extent - (MARGIN * 2)

        start.clamp(MARGIN, extent - MARGIN - size_of)
      end
    end
  end
end
