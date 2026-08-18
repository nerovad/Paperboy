# frozen_string_literal: true

require 'test_helper'

class DatabaseDslCreatorTest < ActiveSupport::TestCase
  test 'syncs a selected SQL Server table into a DSL' do
    catalog = Object.new
    catalog.define_singleton_method(:databases) { |_server| ['GSABSS'] }
    catalog.define_singleton_method(:tables) { |_server, _database| ['dbo.SampleTable'] }
    status = Struct.new(:success?).new(true)
    commands = []
    runner = lambda do |*arguments, **options|
      commands << [arguments, options]
      ['Imported', status]
    end
    entry = Struct.new(:config).new({ header: [['id', 'id', 'int', 'NOT NULL', nil]] })

    Open3.stub(:capture2e, runner) do
      DslCatalog.stub(:reload!, nil) do
        DslCatalog.stub(:find!, entry) do
          slug = DatabaseDslCreator.new(
            server: 'GSASQL16', database: 'GSABSS', table: 'dbo.SampleTable', catalog: catalog
          ).create!

          assert_equal 'SampleTable', slug
        end
      end
    end

    expected_commands = [
      ['DataRunner:dsl_stub', 'GSASQL16.GSABSS.dbo.SampleTable'],
      ['DataRunner:dump_sql', 'SampleTable'],
      ['DataRunner:use_sql', 'SampleTable'],
      ['DataRunner:from_sql', 'SampleTable']
    ]
    actual_commands = commands.map { |command, _options| command.last(2) }
    assert_equal expected_commands, actual_commands
    assert(commands.all? { |_command, options| options.fetch(:chdir) == Rails.root.to_s })
  end

  test 'previews the validated target without creating a DSL' do
    catalog = Object.new
    catalog.define_singleton_method(:databases) { |_server| ['GSABSS'] }
    catalog.define_singleton_method(:tables) { |_server, _database| ['dbo.SampleTable'] }

    preview = DatabaseDslCreator.new(
      server: 'GSASQL16', database: 'GSABSS', table: 'dbo.SampleTable', catalog: catalog
    ).preview!

    assert_equal %w[GSASQL16 GSABSS dbo SampleTable], preview.to_a
  end

  test 'rejects database and table values not returned by the server' do
    catalog = Object.new
    catalog.define_singleton_method(:databases) { |_server| ['GSABSS'] }
    catalog.define_singleton_method(:tables) { |_server, _database| ['dbo.KnownTable'] }

    error = assert_raises(DatabaseDslCreator::ImportFailed) do
      DatabaseDslCreator.new(
        server: 'GSASQL16', database: 'Other', table: 'dbo.Unknown', catalog: catalog
      ).create!
    end

    assert_equal 'Select a database.', error.message
  end
end
