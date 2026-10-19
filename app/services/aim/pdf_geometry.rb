# frozen_string_literal: true

module Aim
  # Where things go on a page as a person sees it (#181): the page turned by
  # its /Rotate and cut to its crop box, with the origin at the bottom left as
  # displayed. The editor works in fractions of that view; these turn them
  # into the page's own coordinates. The same sums as Aim::PdfStamp's.
  module PdfGeometry
    LEADING = 1.2

    module_function

    # The seen page's width and height, and the matrix from seen coordinates
    # to the page's own.
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

    # A content stream writing +texts+ ({ x:, y:, size:, text: }, x and y
    # fractions of the seen page from its top left to the text's top left)
    # in black Helvetica. Starts with Q, to follow a page wrapped in q.
    def text_stream(box, rotate, texts, font)
      width, height, matrix = orientation(box, rotate)
      body = "Q\nq\n#{matrix.map { |n| PdfWriter.number(n) }.join(' ')} cm\n0 g\nBT\n"
      texts.each do |text|
        size = text[:size].to_f.clamp(4.0, 72.0)
        x = text[:x].to_f.clamp(0.0, 1.0) * width
        top = (1 - text[:y].to_f.clamp(0.0, 1.0)) * height
        text[:text].to_s.split(/\r?\n/).each_with_index do |line, index|
          y = top - (size * ((index * LEADING) + 1))
          body << "/#{font} #{PdfWriter.number(size)} Tf\n1 0 0 1 #{PdfWriter.number(x)} #{PdfWriter.number(y)} Tm\n#{literal(line)} Tj\n"
        end
      end
      body << "ET\nQ\n"
    end

    def literal(text)
      bytes = text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?').b
      "(#{bytes.gsub(/[\\()]/) { |char| "\\#{char}" }})"
    end
  end
end
