# frozen_string_literal: true

require 'fileutils'

# Shared SQL Server helper methods for ETL stage scripts.
module MssqlHelpers
  KERBEROS_LOCK = Mutex.new

  module_function

  def load_dotenv!(env_path = File.expand_path('../../../../.env', __dir__))
    return unless File.exist?(env_path)

    File.read(env_path).each_line do |line|
      key, value = parse_env_line(line)
      next if key.nil?

      ENV[key] = value unless ENV.key?(key)
    end
  end

  def parse_env_line(line)
    stripped = line.strip
    return nil if stripped.empty? || stripped.start_with?('#')
    return nil unless stripped.include?('=')

    key, value = stripped.split('=', 2)
    key = key.to_s.strip
    value = unquote(value.to_s.strip)
    [key, value]
  end

  def unquote(value)
    if (value.start_with?('"') && value.end_with?('"')) ||
       (value.start_with?("'") && value.end_with?("'"))
      value[1..-2]
    else
      value
    end
  end

  def env!(key)
    value = ENV[key].to_s
    raise "missing ENV #{key}" if value.strip.empty?

    value
  end

  def env_any(*keys)
    keys.each do |key|
      value = ENV[key].to_s
      return value unless value.strip.empty?
    end
    nil
  end

  def env_any!(*keys)
    value = env_any(*keys)
    return value unless value.nil?

    raise "missing ENV (any of: #{keys.join(', ')})"
  end

  def env_bool(key, default: false)
    value = ENV.fetch(key, nil)
    return default if value.nil?

    %w[1 true yes y on].include?(value.to_s.strip.downcase)
  end

  def connect!(host = nil, database: nil, kerberos: nil)
    require 'tiny_tds'

    resolved_host = host.to_s.strip.empty? ? env_any!('MSSQL_HOST', 'GSABSS_HOST') : host
    use_kerberos = kerberos.nil? ? kerberos_host?(resolved_host) : kerberos
    open_client(connection_options(resolved_host, database, use_kerberos), kerberos: use_kerberos)
  end

  # Auth mode mirrors config/database.yml: a username present means SQL/NTLM
  # auth (used by CI, which has no AD); absent means Kerberos (GSSAPI) using
  # the ticket in KRB5CCNAME. Kerberos needs tiny_tds built against the system
  # FreeTDS - the precompiled gem ships without GSSAPI support. SQL22_HOST is
  # reached with that ticket even when GSAETL is configured for GSASQL16.
  def connection_options(host, database, use_kerberos)
    timeout = env_any('MSSQL_TIMEOUT', 'GSABSS_TIMEOUT').to_s.strip
    timeout_i = timeout.empty? ? nil : timeout.to_i
    opts = {
      host: host,
      port: (env_any('MSSQL_PORT', 'GSABSS_PORT') || '1433').to_i,
      tds_version: ENV['MSSQL_TDSVER'] || '7.4'
    }
    append_sql_login!(opts) unless use_kerberos
    opts[:timeout] = timeout_i if timeout_i&.positive?
    opts[:encrypt] = env_bool('MSSQL_ENCRYPT', default: false) if ENV.key?('MSSQL_ENCRYPT')
    opts[:database] = selected_database(database, use_kerberos)
    opts.compact
  end

  def append_sql_login!(opts)
    username = env_any('MSSQL_USERNAME', 'GSABSS_USERNAME')
    return if username.to_s.strip.empty?

    opts[:username] = username
    opts[:password] = env_any!('MSSQL_PASSWORD', 'GSABSS_PASSWORD')
  end

  def selected_database(database, use_kerberos)
    requested = database.to_s.strip
    return requested unless requested.empty?
    return nil if use_kerberos

    env_any('MSSQL_DATABASE', 'GSABSS_DATABASE').to_s.strip.presence
  end

  def kerberos_host?(host)
    value = host.to_s.strip.downcase
    return false if value.empty?

    ENV['SQL22_HOST'].to_s.strip.casecmp?(value)
  end

  def open_client(opts, kerberos:)
    return TinyTds::Client.new(**opts) unless kerberos

    with_kerberos_config { TinyTds::Client.new(**opts) }
  end

  def with_kerberos_config
    realm = ENV['KRB5_REALM'].to_s.strip
    return yield unless realm.match?(/\A[A-Za-z0-9._-]+\z/)

    KERBEROS_LOCK.synchronize do
      previous = ENV.fetch('KRB5_CONFIG', nil)
      ENV['KRB5_CONFIG'] = kerberos_config_path(realm)
      yield
    ensure
      if previous.nil?
        ENV.delete('KRB5_CONFIG')
      else
        ENV['KRB5_CONFIG'] = previous
      end
    end
  end

  def kerberos_config_path(realm)
    path = File.expand_path("../../../../tmp/krb5-#{realm}.conf", __dir__)
    FileUtils.mkdir_p(File.dirname(path))
    body = kerberos_config_body(realm)
    File.write(path, body) unless File.file?(path) && File.read(path) == body
    path
  end

  def kerberos_config_body(realm)
    lines = [
      '[libdefaults]',
      "\tdefault_realm = #{realm}",
      "\tdns_lookup_kdc = true",
      "\tdns_lookup_realm = false"
    ]
    domain = ENV['SQL22_HOST'].to_s.strip.split('.', 2).last
    if domain.to_s.include?('.')
      lines << '[domain_realm]'
      lines << "\t.#{domain} = #{realm}"
      lines << "\t#{domain} = #{realm}"
    end
    "#{lines.join("\n")}\n"
  end

  def quote_ident(value)
    "[#{value.to_s.gsub(']', ']]')}]"
  end

  def sql_qualified(schema, table)
    "#{quote_ident(schema)}.#{quote_ident(table)}"
  end

  def target_label(*parts)
    label = parts.compact.map(&:to_s).reject(&:empty?).join('.')
    label.empty? ? 'target unresolved' : label
  end
end
