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

      def apply(matrix, x, y)
        a, b, c, d, e, f = matrix
        [(a * x) + (c * y) + e, (b * x) + (d * y) + f]
      end
    end
  end
end
