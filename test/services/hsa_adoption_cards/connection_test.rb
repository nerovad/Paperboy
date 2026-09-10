# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  # Never opens a socket: only the options a client would be built with.
  class ConnectionTest < ActiveSupport::TestCase
    MANAGED = %w[HSA_ADOPT_SQL_HOST HSA_ADOPT_SQL_PORT HSA_ADOPT_SQL_DATASERVER HSA_ADOPT_SQL_DATABASE
                 HSA_ADOPT_SQL_USERNAME HSA_ADOPT_SQL_PASSWORD HSA_ADOPT_SQL_TIMEOUT
                 GSABSS_USERNAME GSABSS_PASSWORD GSABSS_TIMEOUT].freeze

    setup do
      @old_env = MANAGED.to_h { |key| [key, ENV.fetch(key, nil)] }
      MANAGED.each { |key| ENV.delete(key) }
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    test 'host and port with no credentials means Kerberos' do
      ENV['HSA_ADOPT_SQL_HOST'] = 'sql.example.test'
      options = Connection.new.options

      assert_equal 'sql.example.test', options[:host]
      assert_equal 1433, options[:port]
      assert_equal 'GSA_Scan', options[:database]
      assert_equal 5, options[:timeout]
      refute options.key?(:username)
    end

    test 'a named instance can be given as a dataserver instead' do
      ENV['HSA_ADOPT_SQL_HOST'] = 'ignored'
      ENV['HSA_ADOPT_SQL_DATASERVER'] = 'gsa-sql22\gsasql22'
      options = Connection.new.options

      assert_equal 'gsa-sql22\gsasql22', options[:dataserver]
      refute options.key?(:host)
    end

    test 'the GSABSS credentials are never used for this instance' do
      ENV['HSA_ADOPT_SQL_HOST'] = 'sql.example.test'
      ENV['GSABSS_USERNAME'] = 'ci_user'
      ENV['GSABSS_PASSWORD'] = 'ci_pass'
      refute Connection.new.options.key?(:username)

      ENV['HSA_ADOPT_SQL_USERNAME'] = 'adopt_user'
      ENV['HSA_ADOPT_SQL_PASSWORD'] = 'adopt_pass'
      assert_equal({ username: 'adopt_user', password: 'adopt_pass' }, Connection.new.options.slice(:username, :password))
    end

    test 'no server at all is loud and names the variable' do
      error = assert_raises(MissingConfiguration) { Connection.new.options }
      assert_includes error.message, 'HSA_ADOPT_SQL_HOST'
    end
  end
end
