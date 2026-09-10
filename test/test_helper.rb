# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'
require_relative 'support/isolated_dsl_catalog'

module ActiveSupport
  class TestCase
    include Rails.application.routes.url_helpers

    BASE_TEST_DATABASE = ActiveRecord::Base.connection_db_config.database
    BASE_TEST_DATABASE_CONFIGURATION = ActiveRecord::Base.connection_db_config.configuration_hash.freeze
    PARALLEL_TEST_DATABASE = "#{BASE_TEST_DATABASE}_#{SecureRandom.hex(6)}".freeze

    class_attribute :parallel_database_run_started, default: false

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, parallelize_databases: false)

    parallelize_before_fork do
      ActiveRecord::Base.connection_handler.clear_all_connections!
      self.parallel_database_run_started = true
    end

    parallelize_setup do |worker|
      ActiveRecord::Base.connection_db_config._database = PARALLEL_TEST_DATABASE
      ActiveRecord::TestDatabases.create_and_load_schema(worker, env_name: Rails.env)

      database_config = ActiveRecord::Base.connection_db_config
      expected_database = "#{PARALLEL_TEST_DATABASE}_#{worker}"
      raise "Refusing to manage unexpected test database #{database_config.database.inspect}" unless
        database_config.database == expected_database

      DslCatalog.reload!
    end

    # Keep global fixtures to records used by active tests. Placeholder
    # lookup fixtures can overflow short SQL Server string primary keys.
    fixtures :probation_transfer_requests

    # Add more helper methods to be used by all tests here...
  end
end

Minitest.after_run do
  next unless ActiveSupport::TestCase.parallel_database_run_started

  ActiveRecord::Base.connection_handler.clear_all_connections!
  Minitest.parallel_executor.size.times do |worker|
    database = "#{ActiveSupport::TestCase::PARALLEL_TEST_DATABASE}_#{worker}"
    configuration = ActiveSupport::TestCase::BASE_TEST_DATABASE_CONFIGURATION.merge(database: database)
    ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
  end
end
