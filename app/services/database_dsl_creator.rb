# frozen_string_literal: true

require 'open3'

class DatabaseDslCreator
  class ImportFailed < StandardError; end

  Preview = Data.define(
    :server, :database, :schema, :table,
    :replicate, :target_server, :target_database, :target_schema, :target_table,
    :slug, :key, :group, :local, :headers
  ) do
    def to_a = deconstruct
  end
  IDENTIFIER = /\A[A-Za-z0-9_]+\z/

  def initialize(server:, database:, table:, replicate: false, target: {}, catalog: DataRunnerDatabaseCatalog.new,
                 dsl_directory: Rails.root.join('config/data_runner/dsl/other_dsls'),
                 dsl_root: Rails.root.join('config/data_runner/dsl'))
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
    @dsl_root = Pathname.new(dsl_root)
    @headers = []
  end

  def create!
    preview = preview!
    if preview.replicate
      write_replication_dsl!(preview)
      DslCatalog.reload!
      return preview.slug
    end

    table_name = preview.table
    create_initial_dsl!(preview) unless dsl_path(table_name).file?
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
    slug = @replicate ? DatabaseReplicationDsl.slug_for(@database, table_name) : table_name
    group = @replicate ? DatabaseReplicationDsl.group_name(@database) : nil
    Preview.new(
      server: @server, database: @database, schema: schema, table: table_name,
      replicate: @replicate,
      target_server: @target_server, target_database: @target_database,
      target_schema: @target_schema, target_table: @target_table,
      slug: slug, key: slug.to_s.sub(/\A./, &:upcase), group: group,
      local: (@replicate ? "#{slug}.csv" : nil), headers: @headers
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

  def write_replication_dsl!(preview)
    DatabaseReplicationDsl.write!(preview, @dsl_root)
  rescue DatabaseReplicationDsl::AlreadyExists => e
    raise ImportFailed, e.message
  end

  def validate_selection!
    selection = DatabaseDslSelection.new(
      catalog: @catalog, server: @server, database: @database, table: @table, replicate: @replicate,
      target: { server: @target_server, database: @target_database, schema: @target_schema, table: @target_table }
    )
    @headers = selection.headers
  end
end
