# frozen_string_literal: true

# Shared SQL Server helper methods for ETL stage scripts.
module MssqlHelpers
  module_function

  def load_dotenv!(env_path = File.expand_path('../../.env', __dir__))
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
    [ key, value ]
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

  def connect!(host = nil, database: nil)
    require 'tiny_tds'

    timeout = env_any('MSSQL_TIMEOUT', 'GSABSS_TIMEOUT').to_s.strip
    timeout_i = timeout.empty? ? nil : timeout.to_i

    opts = {
      host: host.to_s.strip.empty? ? env_any!('MSSQL_HOST', 'GSABSS_HOST') : host,
      port: (env_any('MSSQL_PORT', 'GSABSS_PORT') || '1433').to_i,
      tds_version: ENV['MSSQL_TDSVER'] || '7.4',
      username: env_any!('MSSQL_USERNAME', 'GSABSS_USERNAME'),
      password: env_any!('MSSQL_PASSWORD', 'GSABSS_PASSWORD')
    }

    opts[:timeout] = timeout_i if timeout_i&.positive?
    opts[:encrypt] = env_bool('MSSQL_ENCRYPT', default: false) if ENV.key?('MSSQL_ENCRYPT')
    requested_database = database.to_s.strip
    env_database = env_any('MSSQL_DATABASE', 'GSABSS_DATABASE').to_s.strip
    opts[:database] = requested_database unless requested_database.empty?
    opts[:database] = env_database if requested_database.empty? && !env_database.empty?

    TinyTds::Client.new(**opts)
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
