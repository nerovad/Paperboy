# frozen_string_literal: true

require 'test_helper'

module Paperboy
  module Pdf
    # Stamp areas written onto a PDF: every page or some, any face and
    # colour, on turned pages as they are seen, and the source left alone.
    class StampTest < ActiveSupport::TestCase
      setup { @dir = Dir.mktmpdir }
      teardown { FileUtils.rm_rf(@dir) }

      def source(pages: 2, rotate: nil)
        path = File.join(@dir, 'source.pdf')
        Prawn::Document.generate(path) do |doc|
          pages.times do |index|
            doc.start_new_page if index.positive?
            doc.text "Page #{index + 1}"
          end
        end
        return path unless rotate

        turned = File.join(@dir, 'turned.pdf')
        Aim::PdfEdit.new(path).write(turned, (1..pages).map { |page| { source: 0, page: page, rotate: rotate } })
        turned
      end

      def stamp(path, *boxes)
        out = File.join(@dir, 'stamped.pdf')
        result = Stamp.new(path).write(out) { boxes }
        [PDF::Reader.new(out), result]
      end

      def box(**settings) = StampBox.build({ lines: ['APPROVED'] }.merge(settings))

      test 'every page is stamped, the source is untouched, and the page keeps its own text' do
        path = source
        before = File.binread(path)

        reader, result = stamp(path, box(lines: %w[APPROVED Martinez]))

        assert_equal before, File.binread(path)
        assert_empty result.warnings
        reader.pages.each_with_index do |page, index|
          assert_includes page.text, "Page #{index + 1}"
          assert_includes page.text, 'APPROVED'
          assert_includes page.text, 'Martinez'
        end
      end

      test 'areas can be kept to the first or the last page' do
        reader, = stamp(source(pages: 3), box(lines: ['FIRST'], pages: 'first'), box(lines: ['LAST'], pages: 'last'))

        texts = reader.pages.map(&:text)
        assert_equal([true, false, false], texts.map { |text| text.include?('FIRST') })
        assert_equal([false, false, true], texts.map { |text| text.include?('LAST') })
      end

      test 'each face is its own standard font; a see-through background is a graphics state' do
        reader, = stamp(source(pages: 1), box(font: 'times', bold: true), box(font: 'courier', italic: true, opacity: 0.4))

        resources = reader.pages.first.attributes[:Resources]
        fonts = reader.objects.deref(resources[:Font]).values.map { |ref| reader.objects.deref(ref)[:BaseFont] }
        states = reader.objects.deref(resources[:ExtGState]).values.map { |ref| reader.objects.deref(ref)[:ca] }
        assert_includes fonts, :'Times-Bold'
        assert_includes fonts, :'Courier-Oblique'
        assert_equal [0.4], states
      end

      test 'on a turned page the stamp lands in the corner as the page is seen' do
        reader, = stamp(source(pages: 1, rotate: 90), box(lines: ['STAMPED'], anchor: 'bottom_right', x: 10, y: 10))

        runs = reader.pages.first.runs
        stamped = runs.find { |run| run.text == 'STAMPED' }
        page_text = runs.find { |run| run.text != 'STAMPED' }
        assert_operator stamped.x, :>, 700, 'at the right of the 792-point-wide page as seen'
        assert_operator page_text.y - stamped.y, :>, 500, 'at the bottom, well below the page text at the top'
      end

      test 'an area pushed off the page is reported, page by page' do
        _, result = stamp(source(pages: 2), box(anchor: 'top_left', x: -500, y: -500))

        assert_equal({ 1 => [:moved_inside], 2 => [:moved_inside] }, result.warnings)
      end

      test 'a turned area and a clear background are drawn; the clear one adds no fill' do
        reader, = stamp(source(pages: 1), box(lines: ['TURNED'], rotation: 45, background: '#ffff00', opacity: 0))

        stream = reader.pages.first.raw_content
        assert_includes stream, '(TURNED) Tj'
        assert_match(/0\.707 -0\.707 0\.707 0\.707 [\d.]+ [\d.]+ cm/, stream)
        assert_no_match(/1 1 0 rg/, stream, 'no yellow fill for a clear background')
      end

      test "shrinking the page moves its own contents, not the stamp's" do
        path = source(pages: 2)
        out = File.join(@dir, 'shrunk.pdf')
        Stamp.new(path).write(out, shrink: { scale: 0.8, position: 'top' }) { [box(lines: ['ROOM'], pages: 'first')] }

        pages = PDF::Reader.new(out).pages
        page_text = pages.first.runs.find { |run| run.text.start_with?('Page') }
        stamp_text = pages.first.runs.find { |run| run.text == 'ROOM' }
        original = PDF::Reader.new(path).pages.first.runs.first
        assert_in_delta original.font_size * 0.8, page_text.font_size, 0.01
        assert_in_delta (original.y * 0.8) + (792 * 0.2), page_text.y, 0.5, 'shrunk toward the top: the room is left below'
        assert_in_delta 7, stamp_text.font_size, 0.01, 'the stamp is never shrunk'
        assert_includes pages.second.text, 'Page 2', 'every page is shrunk, stamp or not'
      end

      test 'a file that is not a PDF cannot be stamped' do
        path = File.join(@dir, 'bad.pdf')
        File.write(path, 'not a pdf')

        assert_raises(Unwritable) { Stamp.new(path) }
      end
    end
  end
end
