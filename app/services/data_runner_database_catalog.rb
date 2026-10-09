# frozen_string_literal: true

require Rails.root.join('script/ruby/data_runner/db/mssql_helpers')

class DataRunnerDatabaseCatalog
  class ConnectionError < StandardError; end

  SERVER_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9.-]*\z/
  SYSTEM_DATABASES = %w[master model msdb tempdb].freeze
  HIDDEN_SCHEMAS = %w[guest INFORMATION_SCHEMA sys].freeze

  def databases(server)
    with_client(server, database: 'master') do |client|
      names = SYSTEM_DATABASES.map { |name| sql_string(name) }.join(', ')
      client.execute(<<~SQL).map { |row| row.fetch('name') }
        SELECT [name]
        FROM sys.databases
        WHERE [state] = 0 AND HAS_DBACCESS([name]) = 1
          AND [name] NOT IN (#{names})
        ORDER BY [name]
      SQL
    end
  end

  def schemas(server, database)
    raise ConnectionError, 'Database is required.' if database.to_s.blank?

    with_client(server, database: database) do |client|
      hidden = HIDDEN_SCHEMAS.map { |name| sql_string(name) }.join(', ')
      client.execute(<<~SQL).map { |row| row.fetch('name') }
        SELECT s.name
        FROM sys.schemas AS s
        WHERE s.name NOT IN (#{hidden})
          AND NOT EXISTS (
            SELECT 1
            FROM sys.database_principals AS p
            WHERE p.name = s.name AND p.type IN ('R', 'A')
          )
          AND (
            HAS_PERMS_BY_NAME(QUOTENAME(s.name), 'SCHEMA', 'INSERT') = 1
            OR HAS_PERMS_BY_NAME(QUOTENAME(s.name), 'SCHEMA', 'ALTER') = 1
            OR HAS_PERMS_BY_NAME(QUOTENAME(s.name), 'SCHEMA', 'CONTROL') = 1
          )
        ORDER BY s.name
      SQL
    end
  end

  def tables(server, database, schema: nil)
    raise ConnectionError, 'Database is required.' if database.to_s.blank?

    with_client(server, database: database) do |client|
      schema_filter = schema.to_s.strip.empty? ? '' : "AND TABLE_SCHEMA = #{sql_string(schema)}"
      rows = client.execute(<<~SQL)
        SELECT TABLE_SCHEMA AS schema_name, TABLE_NAME AS table_name
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
          #{schema_filter}
        ORDER BY TABLE_SCHEMA, TABLE_NAME
      SQL
      rows.map do |row|
        schema.to_s.strip.empty? ? "#{row.fetch('schema_name')}.#{row.fetch('table_name')}" : row.fetch('table_name')
      end
    end
  end

  def columns(server, database, schema, table)
    raise ConnectionError, 'Table is required.' if schema.to_s.blank? || table.to_s.blank?

    with_client(server, database: database) do |client|
      rows = client.execute(DataRunnerColumnDefinition.query(schema, table))
      rows.filter_map { |row| DataRunnerColumnDefinition.format(row) }
    end
  end

  private

  def sql_string(value)
    "N'#{value.to_s.gsub("'", "''")}'"
  end

  def with_client(server, database:)
    validate_server!(server)
    MssqlHelpers.load_dotenv!
    client = MssqlHelpers.connect!(server, database: database)
    yield client
  rescue ConnectionError
    raise
  rescue StandardError => e
    raise ConnectionError, e.message
  ensure
    client&.close
  end

  def validate_server!(server)
    return if server.to_s.match?(SERVER_PATTERN)

    raise ConnectionError, 'Enter a valid database server.'
  end
end
