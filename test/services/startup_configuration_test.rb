# frozen_string_literal: true

require 'test_helper'

class StartupConfigurationTest < ActiveSupport::TestCase
  setup do
    StartupConfiguration.reset!
  end

  teardown do
    StartupConfiguration.reset!
  end

  test 'reports missing configuration values' do
    warnings = StartupConfiguration.warnings(env: {})

    assert_equal 8, warnings.length
    assert_includes warnings, { key: 'AIM_ROOT', value: '(undefined)', error: 'is not defined.' }
    assert_includes warnings, { key: 'GSABSS_ROOT', value: '(undefined)', error: 'is not defined.' }
    assert_includes warnings, { key: 'GSABSS_HOST', value: '(undefined)', error: 'is not defined.' }
    assert_includes warnings, { key: 'GSABSS_DATABASE', value: '(undefined)', error: 'is not defined.' }
    assert_includes warnings, { key: 'P2M_DATARUNNER_ROOT', value: '(undefined)', error: 'is not defined.' }
    assert_includes warnings, { key: 'BILLING_ARCHIVE_ROOT', value: '(undefined)', error: 'is not defined.' }
    assert_includes warnings, { key: 'DATARUNNER_INBOX', value: '(undefined)', error: 'is not defined.' }
    assert_includes warnings, { key: 'P2M_ROOT', value: '(undefined)', error: 'is not defined.' }
  end

  test 'reports unreachable paths, host, and database' do
    env = {
      'AIM_ROOT' => '/aim', 'GSABSS_ROOT' => '/gsabss',
      'P2M_ROOT' => '/p2m', 'P2M_DATARUNNER_ROOT' => '/datarunner',
      'BILLING_ARCHIVE_ROOT' => '/billing', 'DATARUNNER_INBOX' => '/inbox',
      'GSABSS_HOST' => 'sql.example',
      'GSABSS_DATABASE' => 'GSABSS'
    }

    warnings = StartupConfiguration.warnings(
      env: env,
      directory_checker: ->(_path) { false },
      host_checker: ->(_host, _port) { false },
      database_checker: -> { false }
    )

    assert_equal 8, warnings.length
    assert_includes warnings, { key: 'AIM_ROOT', value: '/aim', error: 'is not reachable.' }
    assert_includes warnings, { key: 'GSABSS_HOST', value: 'sql.example', error: 'is not reachable.' }
    assert(warnings.all? { |warning| warning.fetch(:error) == 'is not reachable.' })
  end

  test 'returns no warnings for reachable configuration' do
    env = {
      'AIM_ROOT' => '/aim', 'GSABSS_ROOT' => '/gsabss',
      'P2M_ROOT' => '/p2m', 'P2M_DATARUNNER_ROOT' => '/datarunner',
      'BILLING_ARCHIVE_ROOT' => '/billing', 'DATARUNNER_INBOX' => '/inbox',
      'GSABSS_HOST' => 'sql.example',
      'GSABSS_DATABASE' => 'GSABSS'
    }

    assert_empty StartupConfiguration.warnings(
      env: env,
      directory_checker: ->(_path) { true },
      host_checker: ->(_host, _port) { true },
      database_checker: -> { true }
    )
  end
end
