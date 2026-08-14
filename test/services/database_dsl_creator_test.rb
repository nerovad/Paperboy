# frozen_string_literal: true

require 'test_helper'

class DatabaseDslCreatorTest < ActiveSupport::TestCase
  test 'syncs a selected SQL Server table into a DSL' do
    catalog = Object.new
    catalog.define_singleton_method(:databases) { |_server| ['GSABSS'] }
    catalog.define_singleton_method(:tables) { |_server, _database| ['dbo.SampleTable'] }
    status = Struct.new(:success?).new(true)
    command = nil
    runner = lambda do |*arguments, **options|
      command = [arguments, options]
      ['Imported', status]
    end

    Open3.stub(:capture2e, runner) do
      DslCatalog.stub(:reload!, nil) do
        slug = DatabaseDslCreator.new(
          server: 'GSASQL16', database: 'GSABSS', table: 'dbo.SampleTable', catalog: catalog
        ).create!

        assert_equal 'SampleTable', slug
      end
    end

    assert_equal ['DataRunner:sync_dsl', 'GSASQL16.GSABSS.dbo.SampleTable'], command.first.last(2)
    assert_equal Rails.root.to_s, command.last.fetch(:chdir)
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
