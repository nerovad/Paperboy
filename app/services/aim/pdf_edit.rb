# frozen_string_literal: true

require 'pdf-reader'

module Aim
  # Builds an edited copy of an invoice's PDF (#181) from the pages a person
  # ended up with in the editor: in their new order, each rotated, cropped,
  # with text boxes on it, some taken from another PDF. The source is never
  # changed.
  #
  # Written with Aim::PdfWriter, as the approval stamp is: every object read
  # with pdf-reader and written out again as a plain PDF. An inserted PDF's
  # objects are renumbered after the source's. Pages left out stay in the
  # file but in no page tree, so nothing shows them.
  #
  # A page is a hash:
  #   source: 0 for the invoice's PDF, n for the nth inserted PDF
  #   page:   its 1-based number there
  #   rotate: degrees to turn it clockwise (a multiple of 90)
  #   crop:   { left:, top:, right:, bottom: }, fractions of the page as
  #           seen (after rotation), from its top left
  #   texts:  text boxes (Aim::PdfTextBox): { x:, y:, w:, h:, size:, text:,
  #           bold:, color:, bg:, border: }, x, y, w and h fractions of the
  #           page as seen (after rotation and crop) from its top left
  class PdfEdit
    class Unreadable < StandardError; end

    FONTS = { regular: :AIMEditFont, bold: :AIMEditFontBold }.freeze

    def initialize(source, inserts: [])
      @docs = [source, *inserts].map { |path| open_doc(path) }
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      raise Unreadable, e.message
    end

    def write(destination, pages) = File.binwrite(destination, render(pages))

    def render(pages)
      raise Unreadable, 'a PDF needs at least one page' if pages.blank?

      out = {}
      main = @docs.first
      main.objects.each { |ref, object| out[[ref.id, ref.gen]] = object unless skipped?(object) }
      @next_id = out.keys.map(&:first).max.to_i + 1
      @docs.drop(1).each { |doc| copy_in(doc, out) }
      catalog = main.objects.deref(main.objects.trailer[:Root])
      pages_ref = catalog[:Pages]
      @fonts = { FONTS[:regular] => add(out, { Type: :Font, Subtype: :Type1, BaseFont: :Helvetica, Encoding: :WinAnsiEncoding }),
                 FONTS[:bold] => add(out, { Type: :Font, Subtype: :Type1, BaseFont: :'Helvetica-Bold', Encoding: :WinAnsiEncoding }) }
      @open_q = add(out, stream("q\n"))
      kids = place(pages, out, pages_ref)
      root_pages = main.objects.deref(pages_ref).except(:Resources, :MediaBox, :CropBox, :Rotate)
      out[[pages_ref.id, pages_ref.gen]] = root_pages.merge(Kids: kids, Count: kids.size)
      PdfWriter.new(main.objects.trailer).write(out)
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, NoMethodError, TypeError, KeyError => e
      raise Unreadable, e.message
    end

    private

    def open_doc(path)
      objects = PDF::Reader.new(path).objects
      raise Unreadable, "#{File.basename(path)} is encrypted" if objects.encrypted?

      PdfSource.new(objects, {})
    end

    def skipped?(object) = object.is_a?(PDF::Reader::Stream) && %i[ObjStm XRef].include?(object.hash[:Type])

    # An inserted PDF's objects, numbered after everything already written.
    def copy_in(doc, out)
      kept = doc.objects.to_a.reject { |_, object| skipped?(object) }
      doc.ids.merge!(kept.each_with_index.to_h { |(ref, _), index| [ref.id, PDF::Reader::Reference.new(@next_id + index, 0)] })
      @next_id += kept.size
      kept.each { |ref, object| out[[doc.ids[ref.id].id, 0]] = doc.remap(object) }
    end

    def add(out, object)
      ref = PDF::Reader::Reference.new(@next_id, 0)
      out[[@next_id, 0]] = object
      @next_id += 1
      ref
    end

    def stream(content) = PDF::Reader::Stream.new({}, content.b)

    def place(pages, out, parent)
      seen = {}
      pages.map do |entry|
        entry = entry.to_h.symbolize_keys
        doc = @docs.fetch(entry[:source].to_i) { raise Unreadable, "there is no PDF number #{entry[:source]}" }
        ref = doc.objects.page_references[entry[:page].to_i - 1]
        raise Unreadable, "page #{entry[:page]} is not in that PDF" if ref.nil? || entry[:page].to_i < 1
        raise Unreadable, "page #{entry[:page]} is used twice" if seen[[entry[:source].to_i, ref.id]]

        seen[[entry[:source].to_i, ref.id]] = true
        new_ref = doc.ids.fetch(ref.id) { ref }
        out[[new_ref.id, new_ref.gen]] = edited_page(doc, ref, entry, parent, out)
        new_ref
      end
    end

    # The page as it will be: its inherited settings made its own (its old
    # parents are gone), turned, cropped, and with its text boxes.
    def edited_page(doc, ref, entry, parent, out)
      page = doc.remap(doc.objects[ref]).dup
      %i[Resources MediaBox CropBox Rotate].each do |key|
        value = doc.inherited_value(ref, key)
        page[key] = doc.remap(value) unless value.nil?
      end
      rotate = (doc.objects.deref(doc.inherited_value(ref, :Rotate)).to_i + entry[:rotate].to_i) % 360
      raise Unreadable, 'a page turns in quarter turns only' unless (rotate % 90).zero?

      page[:Rotate] = rotate
      box = (doc.objects.deref(doc.inherited_value(ref, :CropBox)) || doc.objects.deref(doc.inherited_value(ref, :MediaBox))).map(&:to_f)
      box = PdfGeometry.cropped(box, rotate, entry[:crop]) if entry[:crop].present?
      page[:CropBox] = box
      page[:Parent] = parent
      texts = Array(entry[:texts]).map { |text| text.to_h.symbolize_keys }.select { |text| text[:text].to_s.strip.present? }
      texts.empty? ? page : with_texts(doc, ref, page, [box, rotate], texts, out)
    end

    # The page's content wrapped in q/Q and the text after it, as the stamp
    # does, with the text's font added to its resources: read from the
    # source's own objects, then renumbered.
    def with_texts(doc, ref, page, (box, rotate), texts, out)
      body = PdfGeometry.text_stream(box, rotate, texts, FONTS)
      original = doc.objects[ref]
      contents = doc.objects.deref(original[:Contents])
      contents = [original[:Contents]].compact unless contents.is_a?(Array)
      resources = (doc.objects.deref(doc.inherited_value(ref, :Resources)) || {}).dup
      fonts = (doc.objects.deref(resources[:Font]) || {}).dup
      resources = doc.remap(resources.merge(Font: fonts))
      resources[:Font] = resources[:Font].merge(@fonts)
      page.merge(Contents: [@open_q, *doc.remap(contents), add(out, stream(body))], Resources: resources)
    end
  end
end
