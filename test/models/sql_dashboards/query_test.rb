# frozen_string_literal: true

require 'test_helper'

module SqlDashboards
  class QueryTest < ActiveSupport::TestCase
    include TestAccess

    test 'needs a name, SQL, a known database and a known chart' do
      query = Query.new(database_key: 'billing', chart_type: 'gauge')

      assert_not query.valid?
      assert_equal %i[chart_type database_key name statement], query.errors.attribute_names.sort
    end

    test 'billing is not a database SQL may run against' do
      assert_equal %w[paperboy gsabss], Database.keys
      assert_nil Database.find('billing')
    end

    test 'a database has no pool until the read-only login is set' do
      Database.stub(:configured?, false) do
        assert_raises(Database::NotConfigured) { Database.find('paperboy').pool }
      end
    end

    test 'the read-only connection is the source connection under another login' do
      env = { 'SQL_DASHBOARDS_USERNAME' => ' reader ', 'SQL_DASHBOARDS_PASSWORD' => 'secret',
              'SQL_DASHBOARDS_TIMEOUT' => '12' }
      config = with_env(env) { Database.read_only_config(ApplicationRecord) }
      source = ApplicationRecord.connection_db_config.configuration_hash

      assert_equal 'reader', config[:username]
      assert_equal 'secret', config[:password]
      assert_equal 12_000, config[:timeout]
      assert_equal source[:database], config[:database]
      assert_equal source[:host], config[:host]
    end

    test 'pending_change names what a save is about to do' do
      query = Query.new(name: 'A', database_key: 'paperboy', chart_type: 'table', statement: 'SELECT 1')
      assert_equal 'create', query.pending_change

      query.save!
      assert_nil query.pending_change

      query.statement = 'SELECT 2'
      assert_equal 'update', query.pending_change
    end

    test 'deleting a query takes its cards with it' do
      query = build_query
      dashboard = Dashboard.create!(name: 'Operations')
      dashboard.cards.create!(query: query, position: 1)

      assert_difference 'Card.count', -1 do
        query.destroy!
      end
    end

    test 'a card swaps places with its neighbour' do
      dashboard = Dashboard.create!(name: 'Operations')
      first, second, third = Array.new(3) do |index|
        dashboard.cards.create!(query: build_query(name: "Q#{index}"), position: dashboard.next_position)
      end

      third.move(-1)
      assert_equal [first, third, second], dashboard.cards.reload.to_a

      first.move(-1)
      assert_equal [first, third, second], dashboard.cards.reload.to_a
    end

    private

    def with_env(values)
      before = values.keys.index_with { |key| ENV.fetch(key, nil) }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      before.each { |key, value| ENV[key] = value }
    end
  end
end
