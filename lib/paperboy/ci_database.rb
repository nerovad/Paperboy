# frozen_string_literal: true

module Paperboy
  # Empties the one pre-made CI database and loads the schema into it.
  #
  # The CI login owns the objects inside its database and nothing else; it
  # cannot create or drop databases. Rails' own resets (db:create, db:drop,
  # db:test:purge, db:test:prepare) end in the sqlserver adapter's purge,
  # which drops and re-creates the database, so none of them is used here.
  # Every object is dropped inside the database instead, then the schema
  # file is loaded.
  #
  # Only a database whose name ends in _CI is touched: the configured name is
  # checked before connecting, and the name SQL Server reports is checked
  # again before anything is dropped.
  class CiDatabase
    SUFFIX = '_CI'

    class Refused < StandardError; end

    FOREIGN_KEYS = <<~SQL
      SELECT OBJECT_SCHEMA_NAME(parent_object_id), OBJECT_NAME(parent_object_id), name
      FROM sys.foreign_keys WHERE is_ms_shipped = 0
    SQL

    # Dropped in this order, after the foreign keys: what can depend on a
    # table first, then the tables, then what is left.
    OBJECTS = {
      'VIEW' => 'SELECT SCHEMA_NAME(schema_id), name FROM sys.views WHERE is_ms_shipped = 0 ORDER BY create_date DESC',
      'PROCEDURE' => 'SELECT SCHEMA_NAME(schema_id), name FROM sys.procedures WHERE is_ms_shipped = 0',
      'FUNCTION' => "SELECT SCHEMA_NAME(schema_id), name FROM sys.objects WHERE type IN ('FN', 'IF', 'TF', 'FS', 'FT') AND is_ms_shipped = 0",
      'TABLE' => 'SELECT SCHEMA_NAME(schema_id), name FROM sys.tables WHERE is_ms_shipped = 0',
      'SEQUENCE' => 'SELECT SCHEMA_NAME(schema_id), name FROM sys.sequences WHERE is_ms_shipped = 0',
      'SYNONYM' => 'SELECT SCHEMA_NAME(schema_id), name FROM sys.synonyms WHERE is_ms_shipped = 0',
      'TYPE' => 'SELECT SCHEMA_NAME(schema_id), name FROM sys.types WHERE is_user_defined = 1'
    }.freeze

    # User schemas such as aim, which db/schema.rb creates again. Not dbo,
    # guest, sys or INFORMATION_SCHEMA (ids 1-4), not the fixed database role
    # schemas (16384 and up), and not a schema named after a database user.
    SCHEMAS = <<~SQL
      SELECT s.name FROM sys.schemas s
      WHERE s.schema_id BETWEEN 5 AND 16383
        AND NOT EXISTS (SELECT 1 FROM sys.database_principals p WHERE p.name = s.name)
    SQL

    def self.ci_database?(name)
      name.to_s.end_with?(SUFFIX)
    end

    def self.guard!(name)
      return name if ci_database?(name)

      raise Refused, "Refusing to reset #{name.inspect}: only a database whose name ends in #{SUFFIX} is reset."
    end

    # Empties the database db_config names and loads its schema file.
    def self.reset!(db_config)
      guard!(db_config&.database)
      ActiveRecord::Base.establish_connection(db_config)
      ActiveRecord::Base.connection_pool.with_connection { |connection| new(connection).empty! }
      ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config)
    end

    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    def empty!
      self.class.guard!(connection.select_value('SELECT DB_NAME()'))
      drop_statements.each { |statement| connection.execute(statement) }
    end

    # The statements that empty the database, in the order they run.
    def drop_statements
      foreign_keys + objects + schemas
    end

    private

    def foreign_keys
      connection.select_rows(FOREIGN_KEYS).map do |schema, table, constraint|
        "ALTER TABLE #{qualified(schema, table)} DROP CONSTRAINT #{connection.quote_column_name(constraint)}"
      end
    end

    def objects
      OBJECTS.flat_map do |kind, sql|
        connection.select_rows(sql).map { |schema, name| "DROP #{kind} #{qualified(schema, name)}" }
      end
    end

    def schemas
      connection.select_rows(SCHEMAS).map { |(name)| "DROP SCHEMA #{connection.quote_column_name(name)}" }
    end

    def qualified(schema, name)
      "#{connection.quote_column_name(schema)}.#{connection.quote_column_name(name)}"
    end
  end
end
