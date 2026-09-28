# frozen_string_literal: true

require 'socket'
require 'pathname'
require 'smb_shortcut'

# Checks the configuration Paperboy needs before its integrations can work.
# The result is memoized because this check runs while rendering the layout;
# it is a startup diagnostic, not a health check on every request.
class StartupConfiguration
  PATHS = %w[AIM_ROOT BILLING_ARCHIVE_ROOT DATARUNNER_INBOX GSABSS_ROOT P2M_ROOT P2M_DATARUNNER_ROOT
             P2M_SHIPPING_STATION P2M_STAGING P2M_TEMPORARY_OUTPUT P2M_PROCESSED P2M_DESTROYED
             P2M_PRINTERS].freeze
  P2M_PATHS = PATHS.last(6).freeze

  class << self
    def warnings(env: ENV, directory_checker: method(:directory_reachable?),
                 shortcut_checker: method(:shortcut_reachable?), host_checker: method(:host_reachable?),
                 database_checker: method(:database_reachable?))
      return @warnings if defined?(@warnings)

      @warnings = build_warnings(env, directory_checker, shortcut_checker, host_checker, database_checker).freeze
    end

    # Useful for tests and for a process that deliberately reloads its .env.
    def reset!
      remove_instance_variable(:@warnings) if defined?(@warnings)
    end

    private

    def build_warnings(env, directory_checker, shortcut_checker, host_checker, database_checker)
      warnings = []

      PATHS.each do |key|
        value = configured_value(env, key)
        warnings << warning(key, value, 'is not defined.') unless value
        warnings << warning(key, value, 'is not reachable.') if value && !safe_check do
          checker = shortcut_path?(value) ? shortcut_checker : directory_checker
          checker.call(resolve_path(env, key, value))
        end
      end

      warnings.concat(smb_credential_warnings(env)) if shortcut_paths?(env)

      host = configured_value(env, 'GSABSS_HOST')
      database = configured_value(env, 'GSABSS_DATABASE')
      warnings << warning('GSABSS_HOST', host, 'is not defined.') unless host
      warnings << warning('GSABSS_DATABASE', database, 'is not defined.') unless database

      warnings << warning('GSABSS_HOST', host, 'is not reachable.') if
        host && !safe_check { host_checker.call(host, configured_port(env)) }
      warnings << warning('GSABSS_DATABASE', database, 'is not reachable.') if
        host && database && !safe_check { database_checker.call }

      warnings
    end

    def configured_value(env, key)
      env.fetch(key, nil).to_s.strip.presence
    end

    def configured_port(env)
      Integer(env.fetch('GSABSS_PORT', 1433), 10)
    rescue ArgumentError, TypeError
      1433
    end

    def warning(key, value, detail)
      { key: key, value: value || '(undefined)', error: detail }
    end

    def safe_check
      yield
    rescue StandardError
      false
    end

    def directory_reachable?(path)
      File.directory?(path) && File.readable?(path)
    end

    def shortcut_reachable?(path)
      return false unless File.file?(path) && File.readable?(path)

      SmbShortcut::WindowsShortcut.new(path.to_s).target
      true
    end

    def shortcut_paths?(env)
      PATHS.any? { |key| (value = configured_value(env, key)) && shortcut_path?(value) }
    end

    def shortcut_path?(value)
      Pathname.new(value).extname.casecmp?('.lnk')
    end

    def resolve_path(env, key, value)
      return value unless P2M_PATHS.include?(key)

      path = Pathname.new(value)
      return path.to_s if path.absolute?

      Pathname.new(env.fetch('P2M_DATARUNNER_ROOT', '')).join(path).to_s
    end

    def smb_credential_warnings(env)
      %w[SMB_USERNAME SMB_PASSWORD].filter_map do |key|
        warning(key, '(undefined)', 'is not defined.') unless configured_value(env, key)
      end
    end

    def host_reachable?(host, port)
      Socket.tcp(host, port, connect_timeout: 2) { true }
    end

    def database_reachable?
      GsabssBase.connection.select_value('SELECT 1').to_s == '1'
    end
  end
end
