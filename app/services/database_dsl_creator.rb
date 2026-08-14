# frozen_string_literal: true

require 'open3'

class DatabaseDslCreator
  class ImportFailed < StandardError; end

  IDENTIFIER = /\A[A-Za-z0-9_]+\z/

  def initialize(server:, database:, table:, catalog: DataRunnerDatabaseCatalog.new)
    @server = server.to_s.strip
    @database = database.to_s.strip
    @table = table.to_s.strip
    @catalog = catalog
  end

  def create!
    validate_selection!
    schema, table_name = @table.split('.', 2)
    qualified_name = [@server, @database, schema, table_name].join('.')
    output, status = Open3.capture2e(
      Gem.ruby, Rails.root.join('bin/rake').to_s, 'DataRunner:sync_dsl', qualified_name,
      chdir: Rails.root.to_s
    )
    raise ImportFailed, output unless status.success?

    DslCatalog.reload!
    table_name
  end

  private

  def validate_selection!
    databases = @catalog.databases(@server)
    raise ImportFailed, 'Select a database.' unless databases.include?(@database)
    raise ImportFailed, 'Select a table.' unless @catalog.tables(@server, @database).include?(@table)

    schema, table_name = @table.split('.', 2)
    valid_identifiers = [schema, table_name].all? { |value| value&.match?(IDENTIFIER) }
    raise ImportFailed, 'The selected schema and table must use letters, numbers, and underscores.' unless valid_identifiers
  rescue DataRunnerDatabaseCatalog::ConnectionError => e
    raise ImportFailed, e.message
  end
end
