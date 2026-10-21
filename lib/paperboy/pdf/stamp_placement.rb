# frozen_string_literal: true

module Paperboy
  module Pdf
    # Where a stamp area (Paperboy::Pdf::StampBox) lands on a page, and its
    # lines as wrapped there.
    #
    # The area is anchored and kept on the page by the box its turned shape
    # takes up (for a 45-degree turn, a wider and taller one), and turned
    # about that box's centre. Safety nets, in order: the text wraps to the
    # area's width (or the room the page has along the area's own line); the
    # box is pushed back inside the page's margin; a box that still does not
    # fit shrinks its font down to MIN_SIZE; past that it is placed anyway at
    # MIN_SIZE from the margin. Text is never cut off. Each step taken is a
    # warning.
    class StampPlacement
      # left, bottom, width, height: the area itself, unturned, centred where
      # it lands; outer: [left, bottom, width, height] of the box its turned
      # shape takes up (the same as the area when it is not turned).
      Result = Data.define(:left, :bottom, :width, :height, :rotation, :outer, :size, :lines, :warnings) do
        def top = bottom + height
        def centre = [left + (width / 2), bottom + (height / 2)]
      end

      def initialize(box, page_width, page_height)
        @box = box
        @page_width = page_width
        @page_height = page_height
        @room_width = page_width - (StampBox::MARGIN * 2)
        @room_height = page_height - (StampBox::MARGIN * 2)
      end

      def call
        at = @box.size
        loop do
          wrapped, inner = wrap(at)
          width = inner + (StampBox::PAD * 2)
          height = (wrapped.size * @box.line_height(at)) + (StampBox::PAD * 2)
          outer_width, outer_height = turned(width, height)
          fits = outer_width <= @room_width && outer_height <= @room_height
          return result(at, wrapped, width, height, outer_width, outer_height, fits) if fits || at <= StampBox::MIN_SIZE

          at = [at - 0.5, StampBox::MIN_SIZE].max
        end
      end

      private

      def result(at, wrapped, width, height, outer_width, outer_height, fits)
        warnings = []
        warnings << :shrunk if at < @box.size
        warnings << :too_big unless fits
        left, bottom = anchored(outer_width, outer_height)
        kept_left = keep_inside(left, @page_width, outer_width)
        kept_bottom = keep_inside(bottom, @page_height, outer_height)
        warnings << :moved_inside if (kept_left - left).abs > 0.01 || (kept_bottom - bottom).abs > 0.01
        centre_x = kept_left + (outer_width / 2)
        centre_y = kept_bottom + (outer_height / 2)
        Result.new(left: centre_x - (width / 2), bottom: centre_y - (height / 2), width: width, height: height,
                   rotation: @box.rotation, outer: [kept_left, kept_bottom, outer_width, outer_height],
                   size: at, lines: wrapped, warnings: warnings)
      end

      # The room along the area's own line: the page's width unturned, its
      # height on its side, the smaller of the two on a slant.
      def along
        case @box.rotation % 180
        when 0 then @room_width
        when 90 then @room_height
        else [@room_width, @room_height].min
        end
      end

      def wrap(at)
        limit = [@box.width || Float::INFINITY, along].min - (StampBox::PAD * 2)
        wrapped = @box.lines.flat_map { |line| TextWrap.lines(line, limit) { |text| @box.text_width(text, at) } }
        inner = @box.width ? limit : wrapped.map { |line| @box.text_width(line, at) }.max.to_f
        [wrapped, [inner, limit].min]
      end

      def turned(width, height)
        radians = @box.rotation * Math::PI / 180
        cos = Math.cos(radians).abs
        sin = Math.sin(radians).abs
        [(width * cos) + (height * sin), (width * sin) + (height * cos)]
      end

      def anchored(box_width, box_height)
        vertical, horizontal = @box.anchor == 'center' ? %w[middle center] : @box.anchor.split('_')
        left = case horizontal
               when 'left' then @box.x
               when 'right' then @page_width - @box.x - box_width
               else ((@page_width - box_width) / 2) + @box.x
               end
        bottom = case vertical
                 when 'bottom' then @box.y
                 when 'top' then @page_height - @box.y - box_height
                 else ((@page_height - box_height) / 2) + @box.y
                 end
        [left, bottom]
      end

      def keep_inside(start, extent, size_of)
        return StampBox::MARGIN if size_of > extent - (StampBox::MARGIN * 2)

        start.clamp(StampBox::MARGIN, extent - StampBox::MARGIN - size_of)
      end
    end
  end
end
