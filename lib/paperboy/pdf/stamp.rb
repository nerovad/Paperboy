# frozen_string_literal: true

require 'pdf-reader'

module Paperboy
  module Pdf
    # Writes stamp areas (Paperboy::Pdf::StampBox) onto the pages of a PDF,
    # into a new file. The source is never changed.
    #
    # Every object is read with pdf-reader and written out again as a plain
    # PDF (object streams unpacked, one classic cross-reference table), with
    # each page's content wrapped in q/Q and a stamp stream added after it.
    # That leaves the page exactly as it was, whatever its content does to
    # the graphics state. prawn-templates was tried first and failed on one
    # AIM PDF in ten (2026-09-28). Page rotation and the crop box are honoured,
    # so a stamp lands where it was put on the page as it is seen.
    #
    # Moved from Aim::PdfStamp, which wrote one fixed block bottom right
    # (#221).
    class Stamp
      Result = Data.define(:bytes, :warnings)

      def initialize(source)
        @reader = PDF::Reader.new(source)
        @objects = @reader.objects
        raise Unwritable, 'the PDF is encrypted' if @objects.encrypted?
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
        raise Unwritable, e.message
      end

      def page_count = @objects.page_references.size

      # The page as seen, [width, height] in points, for page +index+.
      def page_size(index)
        ref = @objects.page_references.fetch(index)
        width, height, = Geometry.orientation(box_of(ref), rotation_of(ref))
        [width, height]
      end

      # Yields each page's index and the page count, and stamps the boxes the
      # block returns there. Returns a Result: the new file's bytes, and
      # { page number => [warning, ...] } for the pages that needed a safety
      # net. With +check_overlap+, an area over the page's own text is one too
      # (:covers_text; unturned pages only).
      def render(check_overlap: false)
        out = collect_objects
        @next_id = out.keys.map(&:first).max.to_i + 1
        @resources = StampResources.new { |object| add(out, object) }
        open_q = add(out, stream("q\n"))
        warnings = {}
        refs = @objects.page_references
        refs.each_with_index do |ref, index|
          raise Unwritable, 'a page is not an indirect object' unless ref.is_a?(PDF::Reader::Reference)

          boxes = Array(yield(index, refs.size)).select { |box| box.on_page?(index, refs.size) && box.lines.any? }
          next if boxes.empty?

          body, page_warnings = stamp_content(ref, boxes, check_overlap && @reader.page(index + 1))
          warnings[index + 1] = page_warnings if page_warnings.any?
          out[[ref.id, ref.gen]] = stamped_page(ref, open_q, add(out, stream(body)))
        end
        Result.new(bytes: Writer.new(@objects.trailer).write(out), warnings: warnings)
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, NoMethodError, TypeError => e
        raise Unwritable, e.message
      end

      def write(destination, &block)
        result = render(&block)
        File.binwrite(destination, result.bytes)
        result
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
      # stamp's fonts and graphics states added to its (possibly inherited)
      # resources.
      def stamped_page(ref, open_q, stamp)
        page = @objects[ref].dup
        contents = @objects.deref(page[:Contents])
        contents = [page[:Contents]].compact unless contents.is_a?(Array)
        resources = @resources.merged(@objects.deref(inherited_value(ref, :Resources)) || {}) { |value| @objects.deref(value) }
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

      def box_of(ref) = (@objects.deref(inherited_value(ref, :CropBox)) || @objects.deref(inherited_value(ref, :MediaBox))).map(&:to_f)

      def rotation_of(ref) = @objects.deref(inherited_value(ref, :Rotate)).to_i % 360

      # The page's stamp stream and its warnings. +page+ (a PDF::Reader::Page)
      # asks for the overlap check.
      def stamp_content(ref, boxes, page = nil)
        crop = box_of(ref)
        width, height, matrix = Geometry.orientation(crop, rotation_of(ref))
        page = nil unless rotation_of(ref).zero?
        warnings = []
        body = "Q\nq\n#{matrix.map { |n| number(n) }.join(' ')} cm\n"
        boxes.each do |box|
          placed = box.place(width, height)
          warnings.concat(placed.warnings)
          warnings << :covers_text if page && TextOverlap.covers?(page, placed, crop.first(2))
          state = @resources.state_name(box.opacity) if box.background && box.opacity < 1
          body << StampDrawing.draw(box, placed, font: @resources.font_name(box), state: state)
        end
        body << "Q\n"
        [body, warnings.uniq]
      end

      def number(value) = Writer.number(value)
    end
  end
end
