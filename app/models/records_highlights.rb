# frozen_string_literal: true

# A Records table's highlight rules applied to its rows: which rule, if any,
# colours each row (the first match in position order), how many rows each
# rule caught, and the rows one rule caught, for the grid's legend filter.
class RecordsHighlights
  attr_reader :rules

  def initialize(table)
    @rules = RecordsHighlightRule.for_table(table.slug).to_a
    @columns = table.columns.index_by { |c| c.name.to_s }
    @matches = {}.compare_by_identity
  end

  def any? = rules.any?

  def rule_for(row)
    return nil if rules.empty?
    return @matches[row] if @matches.key?(row)

    @matches[row] = rules.find { |rule| rule.matches?(cell(row, rule.column_name)) }
  end

  # { rule => row count } for every rule, zero included.
  def counts(rows)
    tally = rows.filter_map { |row| rule_for(row) }.tally
    rules.to_h { |rule| [rule, tally.fetch(rule, 0)] }
  end

  # A rule that has since been deleted narrows nothing, so a saved view or
  # scheduled export that named it shows every row rather than none.
  def rows_for(rows, rule_id)
    return rows unless rules.any? { |rule| rule.id.to_s == rule_id.to_s }

    rows.select { |row| rule_for(row)&.id.to_s == rule_id.to_s }
  end

  private

  # Only a declared registry column is read, so a rule can never call an
  # arbitrary method on the row.
  def cell(row, column_name)
    return nil unless @columns.key?(column_name)

    row.public_send(column_name)
  end
end
