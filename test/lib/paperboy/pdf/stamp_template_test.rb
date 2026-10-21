# frozen_string_literal: true

require 'test_helper'

module Paperboy
  module Pdf
    # A stamp row's fields, filled.
    class StampTemplateTest < ActiveSupport::TestCase
      VALUES = {
        received: Date.new(2025, 6, 24), at: Time.zone.local(2025, 6, 27, 12, 27, 3), total: BigDecimal('1234.5'),
        credit: BigDecimal('-12.34'), name: 'Martinez, Mark', none: nil
      }.freeze

      def fill(text, **options) = StampTemplate.new(VALUES, **options).fill(text)

      test 'fields take their format, or the default given for them, or a plain date' do
        template = StampTemplate.new(VALUES, formats: { at: '%m/%d/%Y_%H:%M:%S' })

        assert_equal '06/24/2025- 20250624', template.fill('{received}- {received|%Y%m%d}').text
        assert_equal 'Martinez, Mark_06/27/2025_12:27:03', template.fill('{name}_{at}').text
      end

      test 'money, plain numbers and credits' do
        assert_equal '$1,234.50 1234.50 -$12.34', fill('{total} {total|plain} {credit}').text
      end

      test 'text can be upper or lower case' do
        assert_equal 'MARTINEZ, MARK martinez, mark', fill('{name|upper} {name|lower}').text
      end

      test 'a row whose fields are all empty is left out; plain text and part-filled rows stay' do
        template = StampTemplate.new(VALUES, blank: '-')

        assert_equal ['Received 06/24/2025', 'Paid by Fiscal', 'Check - for Martinez, Mark'],
                     template.lines(['Received {received}', '1st: {none}_{none}', 'Paid by Fiscal',
                                     'Check {none} for {name}'])
      end

      test 'the fields a row names' do
        assert_equal %w[received at name], StampTemplate.fields('{received}- {at|%H:%M} {name} {not a field}')
      end
    end
  end
end
