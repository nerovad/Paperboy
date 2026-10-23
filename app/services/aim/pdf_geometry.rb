# frozen_string_literal: true

module Aim
  # Where things go on a page as a person sees it (#181): the page turned by
  # its /Rotate and cut to its crop box, with the origin at the bottom left as
  # displayed. The editor works in fractions of that view; these turn them
  # into the page's own coordinates. The page sums are Paperboy::Pdf::Geometry,
  # shared with the stamp.
  module PdfGeometry
    module_function

    # The seen page's width and height, and the matrix from seen coordinates
    # to the page's own (Paperboy::Pdf::Geometry, shared since #221).
    def orientation(box, rotate) = Paperboy::Pdf::Geometry.orientation(box, rotate)

    def apply(matrix, x, y) = Paperboy::Pdf::Geometry.apply(matrix, x, y)

    # The crop box for { left:, top:, right:, bottom: }, fractions of the
    # seen page from its top left.
    def cropped(box, rotate, crop)
      crop = crop.to_h.symbolize_keys.transform_values(&:to_f)
      left, top, right, bottom = crop.values_at(:left, :top, :right, :bottom).map { |value| value.clamp(0.0, 1.0) }
      raise PdfEdit::Unreadable, 'a crop has to keep some of the page' if right <= left || bottom <= top

      width, height, matrix = orientation(box, rotate)
      corners = [[left * width, (1 - bottom) * height], [right * width, (1 - top) * height]].map { |x, y| apply(matrix, x, y) }
      xs, ys = corners.transpose
      [xs.min, ys.min, xs.max, ys.max]
    end

    # A content stream drawing +texts+ (Aim::PdfTextBox) on the seen page.
    # Starts with Q, to follow a page wrapped in q.
    def text_stream(box, rotate, texts, fonts)
      width, height, matrix = orientation(box, rotate)
      "Q\nq\n#{matrix.map { |n| Paperboy::Pdf::Writer.number(n) }.join(' ')} cm\n#{PdfTextBox.stream(texts, width, height, fonts)}Q\n"
    end

    def literal(text)
      bytes = text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?').b
      "(#{bytes.gsub(/[\\()]/) { |char| "\\#{char}" }})"
    end
  end
end
