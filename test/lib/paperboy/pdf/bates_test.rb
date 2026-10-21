# frozen_string_literal: true

require 'test_helper'

module Paperboy
  module Pdf
    # Bates numbering (#230): a running number on every page, continuous
    # across files, padded by its zeros.
    class BatesTest < ActiveSupport::TestCase
      setup { @dir = Dir.mktmpdir }
      teardown { FileUtils.rm_rf(@dir) }

      def pdf(name, pages)
        path = File.join(@dir, name)
        Prawn::Document.generate(path) do |doc|
          pages.times do |index|
            doc.start_new_page if index.positive?
            doc.text "#{name} page #{index + 1}"
          end
        end
        path
      end

      def texts(bytes) = PDF::Reader.new(StringIO.new(bytes)).pages.map(&:text)

      test 'the zeros of a start set the width' do
        assert_equal([6, 123, '000123'], Bates.from_start('000123').then { |bates| [bates.digits, bates.start, bates.label(123)] })
        assert_equal([1, 7], Bates.from_start('7').then { |bates| [bates.digits, bates.start] })
      end

      test 'a run numbers every page, continuing from one file into the next' do
        areas = [{ 'rows' => ['Some static text {number}'] }, { 'rows' => ['Page {page} of {pages}'], 'anchor' => 'bottom_left' }]

        result = BatesRun.new(Bates.from_start('000001'), areas).stamp([pdf('a.pdf', 2), pdf('b.pdf', 3)])

        assert_equal [1, 5, 5], [result.first_number, result.last_number, result.pages]
        first, second = result.files.map { |bytes| texts(bytes) }
        assert_includes first[1], 'Some static text 000002'
        assert_includes second[0], 'Some static text 000003'
        assert_includes second[2], 'Some static text 000005'
        assert_includes second[2], 'Page 3 of 3'
      end

      test 'a field can set its own width with zeros' do
        result = BatesRun.new(Bates.from_start('42'), [{ 'rows' => ['{number|00000000}'] }]).stamp([pdf('c.pdf', 1)])

        assert_includes texts(result.files.first).first, '00000042'
      end

      test 'with a start page, the pages before it in each file get nothing and take no number' do
        result = BatesRun.new(Bates.from_start('000005'), [{ 'rows' => ['{number} p{page}'] }], first_page: 2)
                         .stamp([pdf('d.pdf', 3), pdf('e.pdf', 2)])

        first, second = result.files.map { |bytes| texts(bytes) }
        assert_not_includes first[0], '00000', 'the cover is left alone'
        assert_includes first[1], '000005 p2'
        assert_includes first[2], '000006 p3'
        assert_not_includes second[0], '00000'
        assert_includes second[1], '000007 p2'
        assert_equal [5, 7, 3], [result.first_number, result.last_number, result.pages]
      end

      test 'the last number is the last the whole set takes, padded alike' do
        result = BatesRun.new(Bates.from_start('000001'), [{ 'rows' => ['{number} of {last_number}'] }])
                         .stamp([pdf('f.pdf', 2), pdf('g.pdf', 3)])

        assert_includes texts(result.files.first).first, '000001 of 000005'
        assert_includes texts(result.files.second).last, '000005 of 000005'
      end
    end
  end
end
