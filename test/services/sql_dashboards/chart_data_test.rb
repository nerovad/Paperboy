# frozen_string_literal: true

require 'test_helper'

module SqlDashboards
  class ChartDataTest < ActiveSupport::TestCase
    def chart(type, columns, rows)
      ChartData.new(chart_type: type, columns: columns, rows: rows)
    end

    test 'a table is never drawn and never a problem' do
      data = chart('table', %w[a], [])

      assert_predicate data, :table?
      assert_not data.drawable?
      assert_nil data.problem
    end

    test 'label and value become pie slices' do
      data = chart('pie', %w[status total], [['Open', 4], ['Closed', BigDecimal('2.5')], [nil, 1]])

      assert_predicate data, :drawable?
      assert_equal 'PieChart', data.chart_class
      assert_equal [['Open', 4], ['Closed', 2.5], ['(none)', 1]], data.series
      assert_empty data.options
    end

    test 'a bar chart is a column chart with its axes named after the columns' do
      data = chart('bar', %w[month requests], [['Jan', 3], ['Feb', 5]])

      assert_equal 'ColumnChart', data.chart_class
      assert_equal [['Jan', 3], ['Feb', 5]], data.series
      assert_equal({ xtitle: 'month', ytitle: 'requests' }, data.options)
    end

    test 'a third column splits a line chart into series' do
      rows = [[Date.new(2026, 1, 1), 3, 'HCA'], [Date.new(2026, 2, 1), 5, 'HCA'], [Date.new(2026, 1, 1), 1, 'GSA']]
      data = chart('line', %w[month requests agency], rows)

      assert_equal [{ name: 'HCA', data: [['2026-01-01', 3], ['2026-02-01', 5]] },
                    { name: 'GSA', data: [['2026-01-01', 1]] }], data.series
    end

    test 'a pie ignores a third column' do
      data = chart('pie', %w[status total agency], [['Open', 4, 'HCA']])

      assert_equal [['Open', 4]], data.series
    end

    test 'a scatter plot keeps both columns as numbers' do
      data = chart('scatter', %w[pages cost], [[10, BigDecimal('1.25')], [20, 3]])

      assert_equal 'ScatterChart', data.chart_class
      assert_equal [[10, 1.25], [20, 3]], data.series
    end

    test 'rows that do not fit the chart say why' do
      assert_equal 'The query returned no rows.', chart('bar', %w[a b], []).problem
      assert_equal 'A pie chart needs at least two columns.', chart('pie', %w[a], [['x']]).problem
      assert_equal 'A bar chart needs a number in its second column (name).',
                   chart('bar', %w[id name], [[1, 'x']]).problem
      assert_equal 'A line chart needs a number in its second column (total).',
                   chart('line', %w[day total], [['Mon', 1], ['Tue', nil]]).problem
      assert_equal 'A scatter plot needs a number in its first column (name).',
                   chart('scatter', %w[name cost], [['x', 1]]).problem
      assert_not chart('scatter', %w[name cost], [['x', 1]]).drawable?
    end
  end
end
