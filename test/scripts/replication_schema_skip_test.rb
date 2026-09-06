# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'

class ReplicationSchemaSkipTest < Minitest::Test
  def test_schema_commands_skip_replication_without_creating_schema_directory
    with_replication do |root, path|
      original = File.read(path)
      %w[dump_sql use_sql].each do |command|
        output = run_command(root, command)
        assert_includes output, '[SKIP] Replica:'
        refute_path_exists File.join(root, 'output/data_runner/04_SQL_SCHEMA')
        assert_equal original, File.read(path)
      end
    end
  end

  def test_existing_snapshot_cannot_replace_destination_mappings_or_post_script
    with_replication do |root, path|
      original = File.read(path)
      schema = File.join(root, 'output/data_runner/04_SQL_SCHEMA/replica.sql')
      FileUtils.mkdir_p(File.dirname(schema))
      File.write(schema, "CREATE TABLE [dbo].[replica](\n[source_only] int NOT NULL\n) ON [PRIMARY]\n")

      assert_includes run_command(root, 'use_sql'), '[SKIP] Replica:'
      assert_equal original, File.read(path)
    end
  end

  def test_non_replication_still_applies_reviewed_schema
    with_replication do |root, path|
      File.write(path, File.read(path).sub('strategy: :replicate', 'strategy: :copy'))
      schema = File.join(root, 'output/data_runner/04_SQL_SCHEMA/replica.sql')
      FileUtils.mkdir_p(File.dirname(schema))
      File.write(schema, "CREATE TABLE [dbo].[replica](\n[reviewed_column] int NOT NULL\n) ON [PRIMARY]\n")

      assert_includes run_command(root, 'use_sql'), '[OK] replica.sql'
      assert_includes File.read(path), 'reviewed_column'
      assert_includes File.read(path), "post_script: 'after_import.rb'"
    end
  end

  private

  def with_replication
    Dir.mktmpdir do |root|
      scripts = File.join(root, 'script/ruby')
      FileUtils.mkdir_p(scripts)
      FileUtils.cp_r(File.expand_path('../../script/ruby/data_runner', __dir__), scripts)
      directory = File.join(root, 'config/data_runner/dsl')
      FileUtils.mkdir_p(directory)
      path = File.join(directory, 'replica.rb')
      File.write(path, <<~RUBY)
        ['Replica', {
          source: { strategy: :replicate, local: 'replica.csv' },
          header: [['source_id', 'destination_id', 'bigint', 'NOT NULL', nil]],
          database_connections: [{ database: 'Target', table: 'replica',
                                   inject: { post_script: 'after_import.rb' } }]
        }]
      RUBY
      yield root, path
    end
  end

  def run_command(root, command)
    script = File.join(root, "script/ruby/data_runner/commands/#{command}.rb")
    output, status = Open3.capture2e({ 'GSABSS_ROOT' => root, 'DATARUNNER_OUTPUT_ROOT' => File.join(root, 'output/data_runner') },
                                     RbConfig.ruby, script, 'Replica')
    assert status.success?, output
    output
  end
end
