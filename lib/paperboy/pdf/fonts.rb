# frozen_string_literal: true

require 'prawn'

module Paperboy
  module Pdf
    # The PDF standard fonts: every reader has them, so nothing is embedded
    # and a stamp looks the same everywhere. Text is written in WinAnsi; a
    # character outside it prints as "?".
    module Fonts
      FAMILIES = {
        'helvetica' => { label: 'Helvetica', regular: 'Helvetica', bold: 'Helvetica-Bold',
                         italic: 'Helvetica-Oblique', bold_italic: 'Helvetica-BoldOblique' },
        'times' => { label: 'Times', regular: 'Times-Roman', bold: 'Times-Bold',
                     italic: 'Times-Italic', bold_italic: 'Times-BoldItalic' },
        'courier' => { label: 'Courier', regular: 'Courier', bold: 'Courier-Bold',
                       italic: 'Courier-Oblique', bold_italic: 'Courier-BoldOblique' }
      }.freeze

      # How far above the baseline a line's capitals reach, as a share of the
      # size: where the first baseline sits under the top of a box.
      ASCENT = 0.8

      module_function

      def family(name) = FAMILIES.key?(name.to_s) ? name.to_s : 'helvetica'

      def style(bold, italic)
        return :bold_italic if bold && italic
        return :bold if bold
        return :italic if italic

        :normal
      end

      # The PostScript name a PDF font dictionary names as BaseFont.
      def base_font(name, bold: false, italic: false)
        face = style(bold, italic)
        FAMILIES.fetch(family(name)).fetch(face == :normal ? :regular : face)
      end

      def width(text, size, name: 'helvetica', bold: false, italic: false)
        metrics(family(name), style(bold, italic)).width_of(text.to_s, size: size)
      end

      # Prawn reads the AFM metrics of the standard fonts; one document per
      # face, kept.
      def metrics(name, face)
        @metrics ||= {}
        @metrics[[name, face]] ||= Prawn::Document.new.tap do |doc|
          doc.font(FAMILIES.fetch(name).fetch(:regular), style: face)
        end
      end
    end
  end
end
