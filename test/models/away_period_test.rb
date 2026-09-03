# frozen_string_literal: true

require 'test_helper'

class AwayPeriodTest < ActiveSupport::TestCase
  def period(**overrides)
    AwayPeriod.create!({ employee_id: '900', delegate_id: '901',
                         starts_on: Date.current, ends_on: 1.week.from_now.to_date }.merge(overrides))
  end

  # --- validations ---

  test 'cannot delegate to yourself' do
    row = AwayPeriod.new(employee_id: '900', delegate_id: '900',
                         starts_on: Date.current, ends_on: Date.current)

    assert_not row.valid?
  end

  test 'cannot end before it starts' do
    row = AwayPeriod.new(employee_id: '900', delegate_id: '901',
                         starts_on: Date.current, ends_on: 1.day.ago.to_date)

    assert_not row.valid?
  end

  test 'a single day away is allowed' do
    assert period(starts_on: Date.current, ends_on: Date.current).valid?
  end

  test 'overlapping periods are refused' do
    period(starts_on: Date.current, ends_on: 5.days.from_now.to_date)
    clash = AwayPeriod.new(employee_id: '900', delegate_id: '902',
                           starts_on: 3.days.from_now.to_date, ends_on: 9.days.from_now.to_date)

    assert_not clash.valid?
  end

  test 'back to back periods are allowed for different people' do
    period
    other = AwayPeriod.new(employee_id: '950', delegate_id: '901',
                           starts_on: Date.current, ends_on: Date.current)

    assert_predicate other, :valid?
  end

  # --- assignee_for ---

  test 'assignee_for returns the id unchanged when nobody is away' do
    assert_equal '900', AwayPeriod.assignee_for('900')
  end

  test 'assignee_for redirects to the delegate while away' do
    period

    assert_equal '901', AwayPeriod.assignee_for('900')
  end

  test 'assignee_for ignores a period that has not started or has ended' do
    period(starts_on: 3.days.from_now.to_date, ends_on: 9.days.from_now.to_date)

    assert_equal '900', AwayPeriod.assignee_for('900')
    assert_equal '901', AwayPeriod.assignee_for('900', on: 4.days.from_now.to_date)
  end

  test 'assignee_for follows a chain of cover' do
    period(employee_id: '900', delegate_id: '901')
    period(employee_id: '901', delegate_id: '902')

    assert_equal '902', AwayPeriod.assignee_for('900')
  end

  test 'assignee_for stops on a circular chain rather than looping' do
    period(employee_id: '900', delegate_id: '901')
    period(employee_id: '901', delegate_id: '900')

    # Either end of the loop is defensible; landing on a real person is not.
    assert_includes %w[900 901], AwayPeriod.assignee_for('900')
  end

  test 'assignee_for passes a blank id straight through' do
    assert_nil AwayPeriod.assignee_for(nil)
    assert_equal '', AwayPeriod.assignee_for('')
  end

  # --- helpers ---

  test 'active_for finds only a period covering the date' do
    row = period

    assert_equal row, AwayPeriod.active_for('900')
    assert_nil AwayPeriod.active_for('900', on: 1.year.from_now.to_date)
  end
end
