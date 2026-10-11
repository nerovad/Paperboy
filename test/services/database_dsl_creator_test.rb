# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module AgenciesCatalogFixture
  def agencies_catalog
    catalog = Object.new
    catalog.define_singleton_method(:databases) do |server|
      server == 'gsa-sql22-tst.example' ? ['Paperboy'] : ['GSABSS']
    end
    catalog.define_singleton_method(:schemas) { |_server, _database| %w[bss dbo] }
    catalog.define_singleton_method(:tables) do |_server, _database, schema: nil|
      schema ? ['agencies'] : ['dbo.agencies']
    end
    catalog.define_singleton_method(:columns) do |_server, _database, _schema, _table|
      [{ name: 'agency_id', data_type: 'nvarchar(3)', nullability: 'NOT NULL' }]
    end
    catalog
  end
end

class DatabaseDslCreatorTest < ActiveSupport::TestCase
  include AgenciesCatalogFixture

  test 'writes a replication dsl named for the source database and table' do
    commands = []
    runner = lambda do |*arguments, **options|
      commands << [arguments, options]
      ['Imported', Struct.new(:success?).new(true)]
    end

    Dir.mktmpdir do |directory|
      Open3.stub(:capture2e, runner) do
        DslCatalog.stub(:reload!, nil) do
          DslCatalog.stub(:entries, []) do
            slug = DatabaseDslCreator.new(
              server: 'GSASQL16', database: 'GSABSS', table: 'dbo.agencies',
              replicate: true,
              target: { server: 'gsa-sql22-tst.example', database: 'Paperboy', schema: 'bss',
                        table: 'agencies' },
              catalog: agencies_catalog, dsl_root: directory
            ).create!

            assert_equal 'gsabss_agencies', slug
            dsl = File.read(File.join(directory, 'gsabss', 'gsabss_agencies.rb'))
            assert_includes dsl, "'Gsabss_agencies'"
            assert_includes dsl, "name: 'gsabss'"
            assert_includes dsl, 'strategy: :replicate'
            assert_includes dsl, "host: 'gsa-sql22-tst.example'"
            assert_includes dsl, "database: 'Paperboy'"
            assert_includes dsl, "schema: 'bss'"
            assert_includes dsl, "table: 'agencies'"
            assert_includes dsl, "local: 'gsabss_agencies.csv'"
            assert_includes dsl, "['agency_id', 'agency_id', 'nvarchar(3)', 'NOT NULL', nil]"
            assert_includes dsl, 'steps: Workflow::REPLICATE_STEPS'
            assert_includes dsl, "scheduled: {\n        enabled: false,"
            assert_not_includes dsl, 'steps: Workflow::MANUAL_STEPS'
            assert_not_includes dsl, 'steps: Workflow::SCHEDULED_STEPS'
            assert_not_includes dsl, '"'
            assert_not_includes dsl, '%i[download to_csv use_dsl inject]'
          end
        end
      end
    end

    assert_empty commands
  end

  test 'does not replace an existing replication dsl' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'gsabss', 'gsabss_agencies.rb')
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, 'existing')

      error = assert_raises(DatabaseDslCreator::ImportFailed) do
        DatabaseDslCreator.new(
          server: 'GSASQL16', database: 'GSABSS', table: 'dbo.agencies',
          replicate: true,
          target: { server: 'gsa-sql22-tst.example', database: 'Paperboy', schema: 'bss', table: 'agencies' },
          catalog: agencies_catalog, dsl_root: directory
        ).create!
      end

      assert_equal 'A DSL for this table already exists.', error.message
      assert_equal 'existing', File.read(path)
    end
  end

  test 'previews the validated replication target without creating a DSL' do
    preview = DatabaseDslCreator.new(
      server: 'GSASQL16', database: 'GSABSS', table: 'dbo.agencies',
      replicate: true,
      target: { server: 'gsa-sql22-tst.example', database: 'Paperboy', schema: 'bss', table: 'agencies' },
      catalog: agencies_catalog
    ).preview!

    assert_equal ['GSASQL16', 'GSABSS', 'dbo', 'agencies', true,
                  'gsa-sql22-tst.example', 'Paperboy', 'bss', 'agencies',
                  'gsabss_agencies', 'Gsabss_agencies', 'gsabss', 'gsabss_agencies.csv'],
                 preview.to_a[0, 13]
    assert_equal 'agency_id', preview.headers.first[:name]
    assert_equal 'nvarchar(3)', preview.headers.first[:data_type]
  end

  test 'normal import does not require a replication target' do
    catalog = Object.new
    catalog.define_singleton_method(:databases) { |_server| ['GSABSS'] }
    catalog.define_singleton_method(:tables) { |_server, _database, schema: nil| schema ? [] : ['dbo.SampleTable'] }

    preview = DatabaseDslCreator.new(
      server: 'GSASQL16', database: 'GSABSS', table: 'dbo.SampleTable', catalog: catalog
    ).preview!

    assert_not preview.replicate
    assert_empty preview.target_server
    assert_empty preview.target_table
    assert_nil preview.group
  end

  test 'rejects database and table values not returned by the server' do
    catalog = Object.new
    catalog.define_singleton_method(:databases) { |_server| ['GSABSS'] }
    catalog.define_singleton_method(:tables) { |_server, _database, schema: nil| schema ? [] : ['dbo.KnownTable'] }

    error = assert_raises(DatabaseDslCreator::ImportFailed) do
      DatabaseDslCreator.new(
        server: 'GSASQL16', database: 'Other', table: 'dbo.Unknown',
        target: { server: 'TARGETSQL', database: 'Reporting', schema: 'dbo', table: 'Unknown' },
        catalog: catalog
      ).create!
    end

    assert_equal 'Select a database.', error.message
  end
end
