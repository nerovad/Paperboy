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
    # from its anchor, into the page. It may be turned in steps of 45
    # degrees, clockwise as seen.
    #
    # Width: nil fits the longest line; a number wraps the text to it.
    # Background: a colour, drawn at +opacity+ (0 is clear); nil for none.
    #
    # Where it lands, and the safety nets, are Paperboy::Pdf::StampPlacement.
    StampBox = Data.define(:lines, :anchor, :x, :y, :width, :align, :font, :bold, :italic, :size, :color,
                           :leading, :background, :opacity, :border, :pages, :rotation)

    class StampBox
      ANCHORS = %w[top_left top_center top_right middle_left center middle_right
                   bottom_left bottom_center bottom_right].freeze
      ALIGNS = %w[left center right].freeze
      PAGES = %w[all first last].freeze
      ROTATIONS = (0...360).step(45).to_a.freeze
      PAD = 2
      MARGIN = 4
      MIN_SIZE = 6.0
      MAX_SIZE = 36.0
      DEFAULTS = {
        lines: [], anchor: 'bottom_right', x: 8.0, y: 8.0, width: nil, align: 'right', font: 'helvetica',
        bold: false, italic: false, size: 7.0, color: '#000000', leading: 8.5 / 7, background: '#ffffff',
        opacity: 1.0, border: false, pages: 'all', rotation: 0
      }.freeze

      # A box from stored settings, every value checked and held to its range.
      def self.build(attributes)
        given = DEFAULTS.merge(attributes.to_h.transform_keys(&:to_sym).slice(*DEFAULTS.keys).compact)
        new(
          lines: Array(given[:lines]).map(&:to_s),
          anchor: one_of(given[:anchor], ANCHORS, :anchor),
          x: given[:x].to_f.clamp(-2000.0, 2000.0), y: given[:y].to_f.clamp(-2000.0, 2000.0),
          width: given[:width].presence && given[:width].to_f.clamp(20.0, 2000.0),
          align: one_of(given[:align], ALIGNS, :align),
          font: Fonts.family(given[:font]), bold: truthy(given[:bold]), italic: truthy(given[:italic]),
          size: given[:size].to_f.clamp(MIN_SIZE, MAX_SIZE), color: colour(given[:color]) || '#000000',
          leading: given[:leading].to_f.clamp(1.0, 3.0), background: colour(given[:background]),
          opacity: given[:opacity].to_f.clamp(0.0, 1.0), border: truthy(given[:border]),
          pages: one_of(given[:pages], PAGES, :pages),
          rotation: ROTATIONS.include?(given[:rotation].to_i % 360) ? given[:rotation].to_i % 360 : 0
        )
      end

      def self.truthy(value) = ActiveModel::Type::Boolean.new.cast(value) || false

      def self.one_of(value, list, default) = list.include?(value.to_s) ? value.to_s : DEFAULTS[default]

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
      # page as seen): a StampPlacement::Result.
      def place(page_width, page_height) = StampPlacement.new(self, page_width, page_height).call
    end
  end
end
