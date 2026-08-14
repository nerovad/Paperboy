# frozen_string_literal: true

require Rails.root.join('script/ruby/data_runner/db/mssql_helpers')

class DataRunnerDatabaseCatalog
  class ConnectionError < StandardError; end

  SERVER_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9.-]*\z/

  def databases(server)
    with_client(server, database: 'master') do |client|
      client.execute(<<~SQL).map { |row| row.fetch('name') }
        SELECT [name]
        FROM sys.databases
        WHERE [state] = 0 AND HAS_DBACCESS([name]) = 1
        ORDER BY [name]
      SQL
    end
  end

  def tables(server, database)
    raise ConnectionError, 'Database is required.' if database.to_s.blank?

    with_client(server, database: database) do |client|
      client.execute(<<~SQL).map { |row| "#{row.fetch('schema_name')}.#{row.fetch('table_name')}" }
        SELECT TABLE_SCHEMA AS schema_name, TABLE_NAME AS table_name
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_SCHEMA, TABLE_NAME
      SQL
    end
  end

  private

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
