# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # The PDF editor's engine (#181): the pages as the person left them, in a
  # new file; the source untouched.
  class PdfEditTest < ActiveSupport::TestCase
    setup { @dir = Dir.mktmpdir }
    teardown { FileUtils.rm_rf(@dir) }

    def pdf(name, pages, size: 'LETTER', rotate: nil)
      path = File.join(@dir, name)
      Prawn::Document.generate(path, page_size: size) do |doc|
        pages.times do |index|
          doc.start_new_page if index.positive?
          doc.text "#{name} page #{index + 1}"
        end
      end
      return path unless rotate

      rotated = File.join(@dir, "rotated-#{name}")
      Aim::PdfEdit.new(path).write(rotated, (1..pages).map { |page| { source: 0, page: page, rotate: rotate } })
      rotated
    end

    def edit(source, pages, inserts: [])
      out = File.join(@dir, 'out.pdf')
      Aim::PdfEdit.new(source, inserts: inserts).write(out, pages)
      PDF::Reader.new(out)
    end

    def texts(reader) = reader.pages.map { |page| page.text.squish }

    test 'pages come out in the new order, the ones left out gone, the source untouched' do
      source = pdf('main', 3)
      before = File.binread(source)

      reader = edit(source, [{ source: 0, page: 3 }, { source: 0, page: 1 }])

      assert_equal ['main page 3', 'main page 1'], texts(reader)
      assert_equal before, File.binread(source)
    end

    test 'pages from another PDF go in where they were put' do
      reader = edit(pdf('main', 2), [{ source: 0, page: 1 }, { source: 1, page: 2 }, { source: 1, page: 1 }, { source: 0, page: 2 }],
                    inserts: [pdf('extra', 2)])

      assert_equal ['main page 1', 'extra page 2', 'extra page 1', 'main page 2'], texts(reader)
    end

    test 'a turn adds to the page own rotation' do
      reader = edit(pdf('main', 2, rotate: 90), [{ source: 0, page: 1, rotate: 90 }, { source: 0, page: 2, rotate: 270 }])

      assert_equal [180, 0], reader.pages.map { |page| page.attributes[:Rotate].to_i }
    end

    test 'a crop is taken from the page as seen, from its top left' do
      reader = edit(pdf('main', 1), [{ source: 0, page: 1, crop: { left: 0.1, top: 0.25, right: 0.6, bottom: 0.75 } }])

      assert_equal [61.2, 198, 367.2, 594], reader.pages.first.attributes[:CropBox].map { |n| n.to_f.round(1) }
    end

    test 'a crop on a turned page is mapped back to the page own coordinates' do
      reader = edit(pdf('main', 1), [{ source: 0, page: 1, rotate: 90, crop: { left: 0, top: 0, right: 0.5, bottom: 1 } }])

      # Turned 90 clockwise, the stored bottom edge is seen on the left, so
      # the left half as seen is the bottom half as stored.
      assert_equal [0, 0, 612, 396], reader.pages.first.attributes[:CropBox].map { |n| n.to_f.round(1) }
    end

    test 'text boxes are written on the page' do
      reader = edit(pdf('main', 1), [{ source: 0, page: 1, texts: [{ x: 0.5, y: 0.5, size: 14, text: "PAID\nCheck 1001" }] }])

      assert_match(/PAID.*Check 1001/m, reader.pages.first.text)
      assert_match(/main page 1/, reader.pages.first.text)
    end

    test 'nonsense is refused, not written' do
      source = pdf('main', 2)
      [[], [{ source: 0, page: 9 }], [{ source: 2, page: 1 }], [{ source: 0, page: 1 }, { source: 0, page: 1 }],
       [{ source: 0, page: 1, rotate: 45 }], [{ source: 0, page: 1, crop: { left: 0.5, right: 0.5, top: 0, bottom: 1 } }]].each do |pages|
        assert_raises(Aim::PdfEdit::Unreadable, pages.inspect) { Aim::PdfEdit.new(source).render(pages) }
      end
    end
  end
end
