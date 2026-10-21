# frozen_string_literal: true

module Paperboy
  module Pdf
    # A page as a person sees it: turned by its /Rotate and cut to its crop
    # box, with the origin at the bottom left as displayed.
    module Geometry
      module_function

      # The seen page's width and height, and the matrix from seen
      # coordinates to the page's own. +box+ is [llx, lly, urx, ury].
      def orientation(box, rotate)
        llx, lly, urx, ury = box
        case rotate
        when 90 then [ury - lly, urx - llx, [0, 1, -1, 0, urx, lly]]
        when 180 then [urx - llx, ury - lly, [-1, 0, 0, -1, urx, ury]]
        when 270 then [ury - lly, urx - llx, [0, -1, 1, 0, llx, ury]]
        else [urx - llx, ury - lly, [1, 0, 0, 1, llx, lly]]
        end
      end

      POSITIONS = %w[center top bottom left right].freeze

      # The page-space transform that shrinks a page's contents to +scale+ of
      # the page as seen and moves them to +position+ (centred, or against
      # the top, bottom, left or right edge), leaving room around them.
      def shrink(box, rotate, scale, position)
        width, height, matrix = orientation(box, rotate)
        left = case position
               when 'left' then 0
               when 'right' then width * (1 - scale)
               else width * (1 - scale) / 2
               end
        bottom = case position
                 when 'bottom' then 0
                 when 'top' then height * (1 - scale)
                 else height * (1 - scale) / 2
                 end
        multiply(multiply(invert(matrix), [scale, 0, 0, scale, left, bottom]), matrix)
      end

      # Affine matrices as PDF writes them, [a b c d e f], applied +first+
      # then +second+.
      def multiply(first, second)
        a, b, c, d, e, f = first
        g, h, i, j, k, l = second
        [(a * g) + (b * i), (a * h) + (b * j), (c * g) + (d * i), (c * h) + (d * j), (e * g) + (f * i) + k, (e * h) + (f * j) + l]
      end

      def invert(matrix)
        a, b, c, d, e, f = matrix.map(&:to_f)
        det = (a * d) - (b * c)
        [d / det, -b / det, -c / det, a / det, ((c * f) - (d * e)) / det, ((b * e) - (a * f)) / det]
      end

      def apply(matrix, x, y)
        a, b, c, d, e, f = matrix
        [(a * x) + (c * y) + e, (b * x) + (d * y) + f]
      end
    end
  end
end
