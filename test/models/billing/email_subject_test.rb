# frozen_string_literal: true

require 'test_helper'

module Billing
  class EmailSubjectTest < ActiveSupport::TestCase
    test 'renders active period placeholders' do
      # rubocop:disable-next Style/FormatStringToken
      subject = EmailSubject.new(
        billing_type: 'GDS',
        subject_format: '%{fiscal_year}.%{apmon} - %{type}'
      )
      period = Struct.new(:fiscal_year, :apmon).new('FY27', 'AP01')

      assert_equal 'FY27.AP01 - GDS', subject.render(period)
    end
  end
end
