# frozen_string_literal: true

require 'test_helper'
require 'erb'
require 'yaml'

class LocalSolidDatabaseConfigTest < ActiveSupport::TestCase
  SYSTEMD_UNITS = %w[
    paperboy-dev.service
    paperboy-dev-jobs.service
    paperboy-stage.service
    paperboy-stage-jobs.service
    paperboy.service
    paperboy-jobs.service
  ].freeze

  test 'development stays on sql server unless the workstation variable is set' do
    shared = render_yaml('config/database.yml', local_solid: nil)
    development = shared.fetch('development')
    database = ENV.fetch('PAPERBOY_DATABASE', 'Paperboy_Dev')

    assert_equal 'sqlserver', development.fetch('adapter')
    assert_equal database, development.fetch('database')
    refute development.key?('queue')
    assert_equal 'sqlserver', shared.fetch('staging').fetch('adapter')
    assert_equal 'sqlserver', shared.fetch('production').fetch('adapter')

    local = render_yaml('config/database.yml', local_solid: '1')
    primary = local.fetch('development').fetch('primary')
    assert_equal 'sqlserver', primary.fetch('adapter')
    assert_equal database, primary.fetch('database')
    assert_sqlite local.fetch('development').fetch('queue'), 'storage/solid_queue.sqlite3', 'db/queue_migrate'
    assert_sqlite local.fetch('development').fetch('cache'), 'storage/solid_cache.sqlite3', 'db/cache_migrate'
    assert_sqlite local.fetch('development').fetch('cable'), 'storage/solid_cable.sqlite3', 'db/cable_migrate'
    assert_equal 'sqlserver', local.fetch('test').fetch('adapter')
    assert_equal 'sqlserver', local.fetch('staging').fetch('adapter')
    assert_equal 'sqlserver', local.fetch('production').fetch('adapter')
  end

  test 'cable uses the local database only for the workstation variable' do
    shared = render_yaml('config/cable.yml', local_solid: nil).fetch('development')
    refute shared.key?('connects_to')
    assert_equal 'test', render_yaml('config/cable.yml', local_solid: nil).fetch('test').fetch('adapter')

    local = render_yaml('config/cable.yml', local_solid: '1').fetch('development')
    assert_equal 'cable', local.dig('connects_to', 'database', 'writing')
    assert_equal 'solid_cable', render_yaml('config/cable.yml', local_solid: '1').fetch('staging').fetch('adapter')
  end

  test 'development connects solid adapters only for the workstation variable' do
    source = File.read(Rails.root.join('config/environments/development.rb'))
    assert_includes source, "if ENV['PAPERBOY_LOCAL_SOLID'] == '1'"
    assert_includes source, 'config.solid_queue.connects_to = { database: { writing: :queue } }'
    assert_includes source, 'config.solid_cache.connects_to = { database: { writing: :cache } }'
  end

  test 'bin/dev prepares the local databases before it boots the app' do
    script = File.read(Rails.root.join('bin/dev-local'))
    export_at = script.index('export PAPERBOY_LOCAL_SOLID=1')
    prepare_at = script.index('local_solid:prepare')
    precompile_at = script.index('assets:precompile')

    assert export_at
    assert prepare_at
    assert precompile_at
    assert_operator export_at, :<, script.index('bundle exec')
    assert_operator prepare_at, :<, precompile_at
  end

  test 'deployed units do not set the workstation variable' do
    SYSTEMD_UNITS.each do |name|
      text = File.read(Rails.root.join('config/systemd', name))
      refute_includes text, 'PAPERBOY_LOCAL_SOLID', name
    end
  end

  private

  def assert_sqlite(config, database, migrations)
    assert_equal 'sqlite3', config.fetch('adapter')
    assert_equal database, config.fetch('database')
    assert_equal migrations, config.fetch('migrations_paths')
    assert_equal 5000, config.fetch('timeout')
  end

  def render_yaml(path, local_solid:)
    original = ENV.fetch('PAPERBOY_LOCAL_SOLID', nil)
    if local_solid.nil?
      ENV.delete('PAPERBOY_LOCAL_SOLID')
    else
      ENV['PAPERBOY_LOCAL_SOLID'] = local_solid
    end
    source = ERB.new(File.read(Rails.root.join(path))).result
    YAML.safe_load(source, aliases: true)
  ensure
    if original.nil?
      ENV.delete('PAPERBOY_LOCAL_SOLID')
    else
      ENV['PAPERBOY_LOCAL_SOLID'] = original
    end
  end
end
