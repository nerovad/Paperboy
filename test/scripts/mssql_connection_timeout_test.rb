# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../script/ruby/data_runner/db/mssql_helpers'

class MssqlConnectionTimeoutTest < Minitest::Test
  TIMEOUT_KEYS = %w[MSSQL_TIMEOUT GSABSS_TIMEOUT MSSQL_USERNAME GSABSS_USERNAME
                    MSSQL_PASSWORD GSABSS_PASSWORD MSSQL_ENCRYPT].freeze

  def test_zero_timeout_overrides_the_five_second_default
    with_env('GSABSS_TIMEOUT' => '5') do
      options = MssqlHelpers.connection_options('db.example', 'Paperboy', false, timeout: 0)

      assert_equal 0, options[:timeout]
    end
  end

  def test_default_timeout_uses_the_environment
    with_env('GSABSS_TIMEOUT' => '5') do
      options = MssqlHelpers.connection_options('db.example', 'Paperboy', false)

      assert_equal 5, options[:timeout]
    end
  end

  private

  def with_env(values)
    previous = TIMEOUT_KEYS.to_h { |key| [key, ENV.fetch(key, nil)] }
    TIMEOUT_KEYS.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    TIMEOUT_KEYS.each do |key|
      value = previous[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
