# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  # Never opens a socket: only the options a client would be built with.
  class ConnectionTest < ActiveSupport::TestCase
    MANAGED = %w[GSABSS_HOST GSABSS_PORT GSABSS_USERNAME GSABSS_PASSWORD GSABSS_TIMEOUT HSA_ADOPT_SQL_DATABASE].freeze

    setup do
      @old_env = MANAGED.to_h { |key| [key, ENV.fetch(key, nil)] }
      MANAGED.each { |key| ENV.delete(key) }
      ENV['GSABSS_HOST'] = 'sql.example.test'
      ENV['GSABSS_PORT'] = '1433'
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    test 'the server, port and timeout are the GSABSS ones, the database is the Scan Center one' do
      ENV['GSABSS_TIMEOUT'] = '9'
      options = Connection.new.options

      assert_equal 'sql.example.test', options[:host]
      assert_equal 1433, options[:port]
      assert_equal 'GSA Scan', options[:database]
      assert_equal 9, options[:timeout]
    end

    test 'no GSABSS credentials means Kerberos' do
      refute Connection.new.options.key?(:username)
    end

    test 'GSABSS credentials are used when set' do
      ENV['GSABSS_USERNAME'] = 'ci_user'
      ENV['GSABSS_PASSWORD'] = 'ci_pass'
      assert_equal({ username: 'ci_user', password: 'ci_pass' }, Connection.new.options.slice(:username, :password))
    end

    test 'the database name can be overridden on its own' do
      ENV['HSA_ADOPT_SQL_DATABASE'] = 'GSA_Scan_Test'
      assert_equal 'GSA_Scan_Test', Connection.new.options[:database]
    end

    test 'a missing server is loud and names the variable' do
      ENV.delete('GSABSS_HOST')
      error = assert_raises(MissingConfiguration) { Connection.new.options }
      assert_includes error.message, 'GSABSS_HOST'
    end
  end
end
