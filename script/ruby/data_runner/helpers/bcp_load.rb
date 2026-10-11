# frozen_string_literal: true

require 'open3'
require_relative '../db/mssql_helpers'

# bcp runs on the DataRunner host and streams the applied file over TDS.
# The SQL Server service never opens the file.
module DataRunner
  class BcpLoad
    BATCH_ROWS = 10_000

    def self.command(executable:, qualified_table:, file:, server:, trusted:, username: nil, password: nil)
      argv = [
        executable, qualified_table, 'in', file.to_s,
        '-S', server,
        '-c', '-C', '65001',
        '-t', '0x1F', '-r', '0x1E',
        '-F', '2', '-E',
        '-b', BATCH_ROWS.to_s,
        '-u'
      ]
      if trusted
        argv << '-T'
      else
        argv.push('-U', username.to_s, '-P', password.to_s)
      end
      argv
    end

    def self.command_for(host:, database:, schema:, table:, file:)
      trusted = MssqlHelpers.kerberos_host?(host)
      username = nil
      password = nil
      unless trusted
        username = MssqlHelpers.env_any('MSSQL_USERNAME', 'GSABSS_USERNAME')
        password = MssqlHelpers.env_any('MSSQL_PASSWORD', 'GSABSS_PASSWORD')
        raise 'missing ENV (any of: MSSQL_USERNAME, GSABSS_USERNAME)' if username.to_s.strip.empty?
        raise 'missing ENV (any of: MSSQL_PASSWORD, GSABSS_PASSWORD)' if password.to_s.strip.empty?
      end

      command(
        executable: executable,
        qualified_table: qualified(database, schema, table),
        file: file,
        server: server_for(host),
        trusted: trusted,
        username: username,
        password: password
      )
    end

    def self.display(argv)
      redacted = argv.dup
      password_flag = redacted.index('-P')
      redacted[password_flag + 1] = '***' if password_flag
      redacted.join(' ')
    end

    def self.run!(argv)
      output, status = execute(argv)
      return if status.success?

      detail = output.to_s.lines.last(20).join
      raise "bcp failed (#{status.exitstatus}): #{detail}"
    rescue Errno::ENOENT
      raise "bcp executable #{argv.first} was not found. Install SQL Server client tools that accept code page 65001."
    end

    def self.execute(argv)
      if argv.include?('-T')
        MssqlHelpers.with_kerberos_config { Open3.capture2e(*argv) }
      else
        Open3.capture2e(*argv)
      end
    end

    def self.executable
      explicit = ENV['BCP_EXECUTABLE'].to_s.strip
      explicit.empty? ? 'bcp' : explicit
    end

    def self.server_for(host)
      port = (MssqlHelpers.env_any('MSSQL_PORT', 'GSABSS_PORT') || '1433').to_s
      port == '1433' ? host.to_s : "#{host},#{port}"
    end

    def self.qualified(database, schema, table)
      [database, schema, table].map { |part| "[#{part.to_s.gsub(']', ']]')}]" }.join('.')
    end
  end
end
