# frozen_string_literal: true

module Paperboy
  module Pdf
    # Whether a placed stamp area sits over text already on the page, for a
    # warning in a preview. Read from pdf-reader's text runs, which are in the
    # page's own coordinates, so only an unturned page is checked; a turned
    # one says nothing rather than guess.
    module TextOverlap
      module_function

      # +page+: a PDF::Reader::Page; +origin+: the crop box's lower left.
      def covers?(page, placed, origin)
        left, bottom = origin
        page.runs.any? do |run|
          next false if run.text.to_s.strip.empty?

          x = run.x - left
          y = run.y - bottom
          x < placed.left + placed.width && x + run.width > placed.left &&
            y < placed.top && y + run.font_size > placed.bottom
        end
      rescue StandardError
        false
      end
    end
  end
end
