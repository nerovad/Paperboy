# frozen_string_literal: true

require 'pdf-reader'
require 'prawn'

module Aim
  # Writes a few lines of text on every page of a PDF, bottom right, over a
  # thin white box, into a new file. The source is never changed.
  #
  # Every object is read with pdf-reader and written out again as a plain PDF
  # (object streams unpacked, one classic cross-reference table), with each
  # page's content wrapped in q/Q and a stamp stream added after it. That
  # leaves the page exactly as it was, whatever its content does to the
  # graphics state. prawn-templates was tried first and failed on one store
  # PDF in ten (2026-09-28). Page rotation is honoured, so the stamp is at the
  # bottom right as the page is seen.
  class PdfStamp
    class Unstampable < StandardError; end

    FONT_SIZE = 7
    LEADING = 8.5
    MARGIN = 10
    PAD = 2
    FONT_NAME = :AIMStampFont

    # Helvetica's widths, for right-aligning the lines.
    def self.metrics = (@metrics ||= Prawn::Document.new.tap { |doc| doc.font('Helvetica') })

    def initialize(source)
      @reader = PDF::Reader.new(source)
      @objects = @reader.objects
      raise Unstampable, 'the PDF is encrypted' if @objects.encrypted?
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      raise Unstampable, e.message
    end

    def write(destination, lines)
      File.binwrite(destination, render(lines))
    end

    def render(lines)
      out = collect_objects
      @next_id = out.keys.map(&:first).max.to_i + 1
      font = add(out, { Type: :Font, Subtype: :Type1, BaseFont: :Helvetica, Encoding: :WinAnsiEncoding })
      open_q = add(out, stream("q\n"))
      @objects.page_references.each do |ref|
        raise Unstampable, 'a page is not an indirect object' unless ref.is_a?(PDF::Reader::Reference)

        stamp = add(out, stream(stamp_content(ref, lines)))
        out[[ref.id, ref.gen]] = stamped_page(ref, font, open_q, stamp)
      end
      serialize(out)
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, NoMethodError, TypeError => e
      raise Unstampable, e.message
    end

    private

    # Every object but the object and cross-reference streams, which the new
    # file does not need: their contents are written as plain objects.
    def collect_objects
      out = {}
      @objects.each do |ref, object|
        next if object.is_a?(PDF::Reader::Stream) && %i[ObjStm XRef].include?(object.hash[:Type])

        out[[ref.id, ref.gen]] = object
      end
      out
    end

    def add(out, object)
      ref = PDF::Reader::Reference.new(@next_id, 0)
      out[[@next_id, 0]] = object
      @next_id += 1
      ref
    end

    def stream(content) = PDF::Reader::Stream.new({}, content.b)

    # The page with its content wrapped in q/Q, the stamp after it, and the
    # stamp's font added to its (possibly inherited) resources.
    def stamped_page(ref, font, open_q, stamp)
      page = @objects[ref].dup
      contents = @objects.deref(page[:Contents])
      contents = [page[:Contents]].compact unless contents.is_a?(Array)
      resources = (@objects.deref(inherited_value(ref, :Resources)) || {}).dup
      fonts = (@objects.deref(resources[:Font]) || {}).dup
      fonts[FONT_NAME] = font
      resources[:Font] = fonts
      page.merge(Contents: [open_q, *contents, stamp], Resources: resources)
    end

    def inherited_value(ref, key)
      node = @objects[ref]
      while node
        return node[key] if node.key?(key)

        node = @objects.deref(node[:Parent])
      end
      nil
    end

    def stamp_content(ref, lines)
      box = (@objects.deref(inherited_value(ref, :CropBox)) || @objects.deref(inherited_value(ref, :MediaBox))).map(&:to_f)
      width, matrix = orientation(box, @objects.deref(inherited_value(ref, :Rotate)).to_i % 360)
      text_width = lines.map { |line| measure(line) }.max
      right = width - MARGIN
      height = (lines.size * LEADING) + (PAD * 2)
      body = "Q\nq\n#{matrix.map { |n| number(n) }.join(' ')} cm\n1 g\n"
      body << "#{number(right - text_width - PAD)} #{number(MARGIN - PAD)} #{number(text_width + (PAD * 2))} #{number(height)} re f\n"
      body << "0 g\nBT\n/#{FONT_NAME} #{FONT_SIZE} Tf\n"
      lines.each_with_index do |line, index|
        y = MARGIN + PAD + ((lines.size - 1 - index) * LEADING) + 1
        body << "1 0 0 1 #{number(right - measure(line))} #{number(y)} Tm\n#{literal(line)} Tj\n"
      end
      body << "ET\nQ\n"
    end

    # The seen page's width, and the matrix from seen coordinates (origin at
    # the bottom left as displayed) to the page's own.
    def orientation(box, rotate)
      llx, lly, urx, ury = box
      case rotate
      when 90 then [ury - lly, [0, 1, -1, 0, urx, lly]]
      when 180 then [urx - llx, [-1, 0, 0, -1, urx, ury]]
      when 270 then [ury - lly, [0, -1, 1, 0, llx, ury]]
      else [urx - llx, [1, 0, 0, 1, llx, lly]]
      end
    end

    def measure(text) = self.class.metrics.width_of(text, size: FONT_SIZE)

    def number(value) = PdfWriter.number(value)

    def literal(text)
      bytes = text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?').b
      "(#{bytes.gsub(/[\\()]/) { |char| "\\#{char}" }})"
    end

    def serialize(out) = PdfWriter.new(@objects.trailer).write(out)
  end
end
