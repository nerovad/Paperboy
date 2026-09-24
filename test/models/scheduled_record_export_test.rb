# frozen_string_literal: true

require 'test_helper'

class ScheduledRecordExportTest < ActiveSupport::TestCase
  def schedule(**attrs)
    ScheduledRecordExport.new({ employee_id: '1001', table_slug: 'fleet', frequency: 'daily',
                                time_of_day: '07:00' }.merge(attrs))
  end

  test 'a view snapshot keeps only the grid query keys, without blanks' do
    kept = ScheduledRecordExport.view_params_from(
      'search' => ' ford ', 'filter_make' => 'Ford', 'filter_budget_unit' => ['', '1100'],
      'sort_by' => 'year', 'sort_direction' => 'desc', 'filter_owner_agency' => '',
      'page' => '2', 'filter_nested' => { 'x' => 'y' }
    )

    assert_equal({ 'search' => 'ford', 'filter_make' => 'Ford', 'filter_budget_unit' => ['1100'],
                   'sort_by' => 'year', 'sort_direction' => 'desc' }, kept)
  end

  test 'a view snapshot of anything but a hash is empty' do
    assert_equal({}, ScheduledRecordExport.view_params_from(nil))
    assert_equal({}, ScheduledRecordExport.view_params_from('filter_make=Ford'))
  end

  test 'describes the saved view with the table column labels' do
    export = schedule(view_params: { 'search' => 'smith', 'filter_make' => 'Ford',
                                     'filter_budget_unit' => %w[1100 1200] })

    assert_equal 'Search "smith" · Make: Ford · Unit: 1100, 1200', export.view_description
    assert_equal 'All rows', schedule(view_params: {}).view_description
  end

  test 'needs a Records table served by the generic grid' do
    assert_predicate schedule, :valid?

    unknown = schedule(table_slug: 'no-such-table')
    assert_not unknown.valid?
    assert_includes unknown.errors[:table_slug], 'is not a Records table'

    # P-Cards has its own screen and its own export.
    pcard = schedule(table_slug: 'pcard')
    assert_not pcard.valid?
    assert_includes pcard.errors[:table_slug], 'has its own export'
  end

  test 'validates the schedule it shares with scheduled reports' do
    assert_not schedule(frequency: 'hourly').valid?
    assert_not schedule(time_of_day: '7am').valid?
    assert_not schedule(frequency: 'weekly', day_of_week: nil).valid?
    assert_predicate schedule(frequency: 'weekly', day_of_week: 1), :valid?
  end

  test 'is due for its first run when created' do
    export = schedule
    export.save!

    assert_not_nil export.next_run_at
    assert_operator export.next_run_at, :>, Time.current
  end

  test 'a saved layout drops columns the table no longer has' do
    assert_equal %w[make year], schedule(layout: %w[make gone year]).columns_layout
    assert_equal TableColumns.default_layout('records:fleet'), schedule(layout: %w[gone]).columns_layout
    assert_equal TableColumns.default_layout('records:fleet'), schedule(layout: nil).columns_layout
  end
end
