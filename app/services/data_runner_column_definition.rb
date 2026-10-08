# frozen_string_literal: true

require Rails.root.join('script/ruby/data_runner/helpers/identity_helpers')

# One source column, shaped the way a replication DSL header row expects it.
class DataRunnerColumnDefinition
  def self.format(row)
    return if sql_true?(row['is_computed']) || row['name'].to_s.strip.empty?

    identity = identity_clause(row)
    nullability = [identity, nullability_clause(row)].compact.reject(&:empty?).join(' ')
    { name: row.fetch('name'), data_type: sql_type(row), nullability: nullability }
  end

  def self.query(schema, table)
    <<~SQL
      SELECT
        c.name,
        typ.name AS type_name,
        type_schema.name AS type_schema,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        c.is_identity,
        CONVERT(varchar(40), ic.seed_value) AS seed_value,
        CONVERT(varchar(40), ic.increment_value) AS increment_value,
        c.is_computed
      FROM sys.columns AS c
      JOIN sys.tables AS t ON t.object_id = c.object_id
      JOIN sys.schemas AS s ON s.schema_id = t.schema_id
      JOIN sys.types AS typ ON typ.user_type_id = c.user_type_id
      JOIN sys.schemas AS type_schema ON type_schema.schema_id = typ.schema_id
      LEFT JOIN sys.identity_columns AS ic
        ON ic.object_id = c.object_id AND ic.column_id = c.column_id
      WHERE s.name = #{quote(schema)} AND t.name = #{quote(table)}
      ORDER BY c.column_id
    SQL
  end

  def self.sql_true?(value)
    value == true || value.to_s == '1'
  end

  def self.sql_type(row)
    type_name = row.fetch('type_name')
    type_schema = row.fetch('type_schema')
    base = type_schema == 'sys' ? type_name : "#{type_schema}.#{type_name}"

    case type_name
    when 'varchar', 'char', 'varbinary', 'binary'
      length = row.fetch('max_length').to_i
      "#{base}(#{length == -1 ? 'max' : length})"
    when 'nvarchar', 'nchar'
      length = row.fetch('max_length').to_i
      "#{base}(#{length == -1 ? 'max' : length / 2})"
    when 'decimal', 'numeric'
      "#{base}(#{row.fetch('precision').to_i},#{row.fetch('scale').to_i})"
    when 'datetime2', 'datetimeoffset', 'time'
      "#{base}(#{row.fetch('scale').to_i})"
    else
      base
    end
  end

  def self.identity_clause(row)
    return '' unless sql_true?(row['is_identity'])

    DataRunner::IdentityHelpers.from_metadata(row)
  end

  def self.nullability_clause(row)
    sql_true?(row['is_nullable']) ? 'NULL' : 'NOT NULL'
  end

  def self.quote(value)
    "N'#{value.to_s.gsub("'", "''")}'"
  end
  private_class_method :sql_true?, :sql_type, :identity_clause, :nullability_clause, :quote
end
