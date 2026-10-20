# frozen_string_literal: true

module SqlDashboards
  # Turns result rows into what a chart draws, by column position.
  #
  # The first column is the label or x value, the second is the value, and an
  # optional third names the series. A scatter plot takes two numbers. There
  # is no chart builder: a query that wants a different chart returns its
  # columns in a different order.
  class ChartData
    # Chartkick's class for each chart type. Its BarChart is horizontal.
    CHARTS = {
      'bar' => 'ColumnChart',
      'line' => 'LineChart',
      'pie' => 'PieChart',
      'scatter' => 'ScatterChart'
    }.freeze

    attr_reader :chart_type, :columns, :rows

    def initialize(chart_type:, columns:, rows:)
      @chart_type = chart_type.to_s
      @columns = columns
      @rows = rows
    end

    def table? = CHARTS.exclude?(chart_type)

    def chart_class = CHARTS[chart_type]

    # Why the rows cannot be drawn as this chart, or nil when they can.
    def problem
      return if table?
      return 'The query returned no rows.' if rows.empty?
      return "A #{label} needs at least two columns." if columns.size < 2
      return "A scatter plot needs a number in its first column (#{columns[0]})." if scatter? && !numeric?(0)

      "A #{label} needs a number in its second column (#{columns[1]})." unless numeric?(1)
    end

    def drawable? = !table? && problem.nil?

    def series
      return points(rows) unless series_column?

      rows.group_by { |row| row[2] }.map { |name, group| { name: text(name), data: points(group) } }
    end

    def options
      return {} if chart_type == 'pie'

      { xtitle: columns[0], ytitle: columns[1] }
    end

    private

    def scatter? = chart_type == 'scatter'

    def label = Query::CHART_TYPES.fetch(chart_type).downcase

    def series_column? = columns.size > 2 && chart_type != 'pie'

    def numeric?(index)
      values = rows.map { |row| row[index] }
      values.any? && values.all?(Numeric)
    end

    def points(group)
      group.map { |row| [scatter? ? number(row[0]) : text(row[0]), number(row[1])] }
    end

    def number(value)
      value.is_a?(Integer) ? value : value.to_f
    end

    def text(value)
      case value
      when nil then '(none)'
      when Time, DateTime then value.iso8601
      else value.to_s
      end
    end
  end
end
