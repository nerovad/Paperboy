# frozen_string_literal: true

# Checks that a database import names a real source, and a real replication target.
class DatabaseDslSelection
  IDENTIFIER = DatabaseDslCreator::IDENTIFIER

  def initialize(catalog:, server:, database:, table:, replicate:, target:)
    @catalog = catalog
    @server = server
    @database = database
    @table = table
    @replicate = replicate
    @target = target
    @headers = []
  end

  def headers
    validate!
    @headers
  end

  private

  def validate!
    databases = @catalog.databases(@server)
    raise DatabaseDslCreator::ImportFailed, 'Select a database.' unless databases.include?(@database)
    raise DatabaseDslCreator::ImportFailed, 'Select a table.' unless @catalog.tables(@server, @database).include?(@table)

    schema, table_name = @table.split('.', 2)
    identifiers = [schema, table_name].all? { |value| value&.match?(IDENTIFIER) }
    raise DatabaseDslCreator::ImportFailed, 'The selected schema and table must use letters, numbers, and underscores.' unless identifiers
    raise DatabaseDslCreator::ImportFailed, 'The source database name cannot be used as a DSL group.' if DatabaseReplicationDsl.group_name(@database).empty?
    raise DatabaseDslCreator::ImportFailed, 'The source table name cannot be used as a DSL name.' if DatabaseReplicationDsl.table_slug(table_name).empty?
    return unless @replicate

    validate_target!(schema, table_name)
  rescue DataRunnerDatabaseCatalog::ConnectionError => e
    raise DatabaseDslCreator::ImportFailed, e.message
  end

  def validate_target!(schema, table_name)
    target_database = @target[:database]
    target_schema = @target[:schema]
    target_table = @target[:table]
    databases = @catalog.databases(@target[:server])
    raise DatabaseDslCreator::ImportFailed, 'Select a target database.' unless databases.include?(target_database)
    raise DatabaseDslCreator::ImportFailed, 'Select a target schema.' unless @catalog.schemas(@target[:server], target_database).include?(target_schema)

    tables = @catalog.tables(@target[:server], target_database, schema: target_schema)
    raise DatabaseDslCreator::ImportFailed, 'Select a target table.' unless tables.include?(target_table)

    identifiers = [target_schema, target_table].all? { |value| value.match?(IDENTIFIER) }
    raise DatabaseDslCreator::ImportFailed, 'Target schema and table must use letters, numbers, and underscores.' unless identifiers

    @headers = @catalog.columns(@server, @database, schema, table_name)
    raise DatabaseDslCreator::ImportFailed, 'The source table has no columns that can be copied.' if @headers.empty?
  end
end
