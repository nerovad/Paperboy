# frozen_string_literal: true

require 'open3'

class DatabaseDslCreator
  class ImportFailed < StandardError; end

  Preview = Data.define(:server, :database, :schema, :table)
  IDENTIFIER = /\A[A-Za-z0-9_]+\z/

  def initialize(server:, database:, table:, catalog: DataRunnerDatabaseCatalog.new)
    @server = server.to_s.strip
    @database = database.to_s.strip
    @table = table.to_s.strip
    @catalog = catalog
  end

  def create!
    preview = preview!
    table_name = preview.table
    qualified_name = [preview.server, preview.database, preview.schema, table_name].join('.')
    run_task!('DataRunner:dsl_stub', qualified_name) unless dsl_path(table_name).file?
    run_task!('DataRunner:dump_sql', table_name)
    run_task!('DataRunner:use_sql', table_name)
    run_task!('DataRunner:from_sql', table_name)

    DslCatalog.reload!
    entry = DslCatalog.find!(table_name)
    raise ImportFailed, 'The database DSL was created without column mappings.' if entry.config.fetch(:header, []).empty?

    table_name
  rescue ActiveRecord::RecordNotFound => e
    raise ImportFailed, e.message
  end

  def preview!
    validate_selection!
    schema, table_name = @table.split('.', 2)
    Preview.new(server: @server, database: @database, schema: schema, table: table_name)
  end

  private

  def run_task!(task, selector)
    output, status = Open3.capture2e(
      Gem.ruby, Rails.root.join('bin/rake').to_s, task, selector,
      chdir: Rails.root.to_s
    )
    raise ImportFailed, output unless status.success?
  end

  def dsl_path(table_name)
    Rails.root.join('config/data_runner/dsl', "#{table_name}.rb")
  end

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
