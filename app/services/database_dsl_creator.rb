# frozen_string_literal: true

require 'open3'

class DatabaseDslCreator
  class ImportFailed < StandardError; end

  Preview = Data.define(
    :server, :database, :schema, :table,
    :replicate, :target_server, :target_database, :target_schema, :target_table
  )
  IDENTIFIER = /\A[A-Za-z0-9_]+\z/

  def initialize(server:, database:, table:, replicate: false, target: {}, catalog: DataRunnerDatabaseCatalog.new,
                 dsl_directory: Rails.root.join('config/data_runner/dsl/other_dsls'))
    @server = server.to_s.strip
    @database = database.to_s.strip
    @table = table.to_s.strip
    @replicate = ActiveModel::Type::Boolean.new.cast(replicate)
    @target_server = target[:server].to_s.strip
    @target_database = target[:database].to_s.strip
    @target_schema = target[:schema].to_s.strip
    @target_table = target[:table].to_s.strip
    @target_table = @table.split('.', 2).last if @replicate && @target_table.empty?
    @catalog = catalog
    @dsl_directory = Pathname.new(dsl_directory)
  end

  def create!
    preview = preview!
    table_name = preview.table
    create_initial_dsl!(preview) unless dsl_path(table_name).file?
    unless preview.replicate
      run_task!('DataRunner:dump_sql', table_name)
      run_task!('DataRunner:use_sql', table_name)
    end
    run_task!('DataRunner:from_sql', table_name)

    DslCatalog.reload!
    return table_name if preview.replicate

    entry = DslCatalog.find!(table_name)
    raise ImportFailed, 'The database DSL was created without column mappings.' if entry.config.fetch(:header, []).empty?

    table_name
  rescue ActiveRecord::RecordNotFound => e
    raise ImportFailed, e.message
  end

  def preview!
    validate_selection!
    schema, table_name = @table.split('.', 2)
    Preview.new(
      server: @server, database: @database, schema: schema, table: table_name,
      replicate: @replicate,
      target_server: @target_server, target_database: @target_database,
      target_schema: @target_schema, target_table: @target_table
    )
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
    @dsl_directory.join("#{table_name}.rb")
  end

  def write_dsl!(preview)
    File.write(dsl_path(preview.table), DatabaseReplicationDsl.render(preview))
  end

  def create_initial_dsl!(preview)
    return write_dsl!(preview) if preview.replicate

    qualified_name = [preview.server, preview.database, preview.schema, preview.table].join('.')
    run_task!('DataRunner:dsl_stub', qualified_name)
  end

  def validate_selection!
    databases = @catalog.databases(@server)
    raise ImportFailed, 'Select a database.' unless databases.include?(@database)
    raise ImportFailed, 'Select a table.' unless @catalog.tables(@server, @database).include?(@table)

    schema, table_name = @table.split('.', 2)
    source_identifiers = [schema, table_name].all? { |value| value&.match?(IDENTIFIER) }
    raise ImportFailed, 'The selected schema and table must use letters, numbers, and underscores.' unless source_identifiers
    return unless @replicate

    target_databases = @catalog.databases(@target_server)
    raise ImportFailed, 'Select a target database.' unless target_databases.include?(@target_database)
    return if [@target_schema, @target_table].all? { |value| value.match?(IDENTIFIER) }

    raise ImportFailed, 'Target schema and table must use letters, numbers, and underscores.'
  rescue DataRunnerDatabaseCatalog::ConnectionError => e
    raise ImportFailed, e.message
  end
end
