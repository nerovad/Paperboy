# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../../lib/paperboy/sql_login'

class SqlLoginTest < Minitest::Test
  KEYS = %w[GSABSS_USERNAME GSABSS_PASSWORD].freeze

  def test_sql_login_is_sent
    assert Paperboy::SqlLogin.sql_credentials?('GSAETL')
    assert_equal({ username: 'GSAETL', password: 'secret' },
                 Paperboy::SqlLogin.credentials('GSAETL', 'secret'))
  end

  def test_blank_username_is_kerberos
    refute Paperboy::SqlLogin.sql_credentials?('  ')
    assert_empty Paperboy::SqlLogin.credentials(nil, 'secret')
  end

  def test_domain_login_on_linux_is_kerberos
    skip 'Windows keeps the domain login for SSPI' if Gem.win_platform?

    refute Paperboy::SqlLogin.sql_credentials?('ENT\\135272')
    assert_empty Paperboy::SqlLogin.credentials('ENT\\135272', 'secret')
  end

  def test_domain_login_in_the_process_yields_to_the_sql_login_in_dotenv
    skip 'Windows keeps the domain login for SSPI' if Gem.win_platform?

    Dir.mktmpdir do |root|
      File.write(File.join(root, '.env'), "GSABSS_USERNAME=GSAETL\nGSABSS_PASSWORD=from-env\n")
      File.write(File.join(root, '.env.local'), "GSABSS_PASSWORD=from-local\n")
      with_env('GSABSS_USERNAME' => 'ENT\\135272', 'GSABSS_PASSWORD' => 'ticket') do
        Paperboy::SqlLogin.prefer_dotenv_sql_login!(root)

        assert_equal 'GSAETL', ENV.fetch('GSABSS_USERNAME')
        assert_equal 'from-local', ENV.fetch('GSABSS_PASSWORD')
      end
    end
  end

  def test_a_sql_login_already_in_the_process_is_left_alone
    Dir.mktmpdir do |root|
      File.write(File.join(root, '.env'), "GSABSS_USERNAME=other\nGSABSS_PASSWORD=from-env\n")
      with_env('GSABSS_USERNAME' => 'GSAETL', 'GSABSS_PASSWORD' => 'kept') do
        Paperboy::SqlLogin.prefer_dotenv_sql_login!(root)

        assert_equal 'GSAETL', ENV.fetch('GSABSS_USERNAME')
        assert_equal 'kept', ENV.fetch('GSABSS_PASSWORD')
      end
    end
  end

  def test_a_domain_login_in_dotenv_is_not_copied_over
    skip 'Windows keeps the domain login for SSPI' if Gem.win_platform?

    Dir.mktmpdir do |root|
      File.write(File.join(root, '.env'), "GSABSS_USERNAME=ENT\\\\125272\nGSABSS_PASSWORD=from-env\n")
      with_env('GSABSS_USERNAME' => 'ENT\\135272', 'GSABSS_PASSWORD' => 'ticket') do
        Paperboy::SqlLogin.prefer_dotenv_sql_login!(root)

        assert_equal 'ENT\\135272', ENV.fetch('GSABSS_USERNAME')
        assert_equal 'ticket', ENV.fetch('GSABSS_PASSWORD')
      end
    end
  end

  private

  def with_env(values)
    previous = KEYS.to_h { |key| [key, ENV.fetch(key, nil)] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    KEYS.each do |key|
      value = previous[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
