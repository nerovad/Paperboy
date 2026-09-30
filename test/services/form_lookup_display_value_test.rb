# frozen_string_literal: true

require 'test_helper'

class FormLookupDisplayValueTest < ActiveSupport::TestCase
  test 'formats a timestamp the way the Records grid shows it' do
    time = Time.utc(2026, 1, 22, 20, 0, 0)

    assert_equal 'Jan 22, 2026 12:00 PM', FormLookup.display_value(time)
  end

  test 'passes non-time values through untouched' do
    assert_equal 'ABC123', FormLookup.display_value('ABC123')
    assert_equal 42, FormLookup.display_value(42)
    assert_nil FormLookup.display_value(nil)
  end
end
