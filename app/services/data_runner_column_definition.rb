# frozen_string_literal: true

require Rails.root.join('script/ruby/data_runner/helpers/column_definition')

# One source column, shaped the way a replication DSL header row expects it.
class DataRunnerColumnDefinition
  def self.format(row)
    DataRunner::ColumnDefinition.format(row)
  end

  def self.query(schema, table)
    DataRunner::ColumnDefinition.query(schema, table)
  end
end
