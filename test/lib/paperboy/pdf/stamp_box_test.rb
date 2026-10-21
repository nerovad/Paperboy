# frozen_string_literal: true

require 'test_helper'

module Paperboy
  module Pdf
    # Where a stamp area lands, and the safety nets that keep it on the page.
    class StampBoxTest < ActiveSupport::TestCase
      LETTER = [612.0, 792.0].freeze

      def box(**settings) = StampBox.build({ lines: ['Approved'] }.merge(settings))

      test 'settings are checked and held to their ranges' do
        built = StampBox.build(lines: ['x'], anchor: 'nowhere', size: 500, color: 'red', background: 'none',
                               font: 'comic', opacity: 3, pages: 'some', align: 'justify')

        assert_equal ['bottom_right', 36.0, '#000000', nil, 'helvetica', 1.0, 'all', 'right'],
                     [built.anchor, built.size, built.color, built.background, built.font, built.opacity, built.pages, built.align]
      end

      test 'an area keeps to its anchor and grows away from it, into the page' do
        corner = box(anchor: 'bottom_right', x: 10, y: 10).place(*LETTER)
        top_left = box(anchor: 'top_left', x: 10, y: 10).place(*LETTER)
        centred = box(anchor: 'center', x: 0, y: 0).place(*LETTER)

        assert_in_delta 612 - 10, corner.left + corner.width, 0.01
        assert_in_delta 10, corner.bottom, 0.01
        assert_in_delta 10, top_left.left, 0.01
        assert_in_delta 792 - 10, top_left.top, 0.01
        assert_in_delta 306, centred.left + (centred.width / 2), 0.01
        assert_empty corner.warnings
      end

      test 'the same offset lands in the same corner of a landscape page' do
        placed = box(anchor: 'bottom_right', x: 10, y: 10).place(792.0, 612.0)

        assert_in_delta 792 - 10, placed.left + placed.width, 0.01
      end

      test 'text wraps to the width given' do
        placed = box(lines: ['one two three four five six seven eight'], width: 60).place(*LETTER)

        assert_operator placed.lines.size, :>, 1
        assert_in_delta 60, placed.width, 0.01
        placed.lines.each { |line| assert_operator Fonts.width(line, placed.size), :<=, 60 - (StampBox::PAD * 2) }
      end

      test 'an area dragged off the page is pushed back inside it' do
        placed = box(anchor: 'bottom_left', x: -200, y: 5000).place(*LETTER)

        assert_in_delta StampBox::MARGIN, placed.left, 0.01
        assert_in_delta 792 - StampBox::MARGIN, placed.top, 0.01
        assert_equal [:moved_inside], placed.warnings
      end

      test 'too tall for the page, the text shrinks; past the smallest size it is stamped anyway, never cut' do
        tall = box(lines: Array.new(80) { |n| "Row #{n}" }, size: 12).place(*LETTER)
        huge = box(lines: Array.new(200) { |n| "Row #{n}" }, size: 12).place(*LETTER)

        assert_operator tall.size, :<, 12
        assert_includes tall.warnings, :shrunk
        assert_operator tall.height, :<=, 792 - (StampBox::MARGIN * 2)
        assert_equal StampBox::MIN_SIZE, huge.size
        assert_includes huge.warnings, :too_big
        assert_equal 200, huge.lines.size, 'every line is kept'
      end

      test 'an area can be kept to the first or last page' do
        first = box(pages: 'first')
        last = box(pages: 'last')

        assert_equal([true, false, false], (0..2).map { |page| first.on_page?(page, 3) })
        assert_equal([false, false, true], (0..2).map { |page| last.on_page?(page, 3) })
      end
    end
  end
end
