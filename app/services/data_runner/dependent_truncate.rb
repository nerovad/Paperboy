# frozen_string_literal: true

module DataRunner
  class DependentTruncate
    Target = Data.define(:name, :host, :database, :schema, :table)

    def self.perform(dsl_names, entries: DslCatalog.entries, connector: nil)
      new(dsl_names, entries, connector).perform
    end

    def initialize(dsl_names, entries, connector)
      @names = Array(dsl_names).map(&:to_s)
      @entries = entries
      @connector = connector
    end

    def perform
      selected.group_by(&:host).flat_map { |host, targets| truncate_host(host, targets) }
    end

    private

    def selected
      @entries.flat_map { |entry| targets_for(entry) }
    end

    def targets_for(entry)
      return [] unless @names.include?(entry.key)

      dependency = entry.config[:dependency].to_s
      return [] if dependency.empty? || @names.exclude?(dependency)

      truncate_connections(entry.config).map { |connection| build_target(entry.key, connection) }
    end

    def truncate_connections(config)
      raw = config[:database_connections] || config[:database_connection]
      list = raw.is_a?(Array) ? raw : [raw].compact
      list.select { |connection| truncate_insert?(config, connection) }
    end

    def truncate_insert?(config, connection)
      mode = connection.dig(:inject, :mode) || config.dig(:inject, :mode) || :truncate_insert
      mode.to_sym == :truncate_insert
    end

    def build_target(name, connection)
      target = Target.new(
        name: name,
        host: connection[:host].to_s.strip,
        database: connection[:database].to_s.strip,
        schema: connection[:schema].to_s.strip,
        table: connection[:table].to_s.strip
      )
      missing = %i[host database schema table].select { |part| target.public_send(part).empty? }
      raise "#{name}: dependent truncate is missing #{missing.join(', ')}" if missing.any?

      target
    end

    def truncate_host(host, targets)
      client = open_client(host)
      targets.map { |target| truncate_target(client, target) }
    ensure
      client&.close
    end

    def truncate_target(client, target)
      client.execute("USE #{quote(target.database)}").do
      client.execute('BEGIN TRAN').do
      client.execute("TRUNCATE TABLE #{quote(target.schema)}.#{quote(target.table)}").do
      client.execute('COMMIT TRAN').do
      "[OK] #{target.name}: truncated #{label(target)} before dependency inject"
    rescue StandardError
      rollback(client)
      raise
    end

    def open_client(host)
      return @connector.call(host) if @connector

      require Rails.root.join('script/ruby/data_runner/db/mssql_helpers')
      MssqlHelpers.connect!(host)
    end

    def rollback(client)
      client.execute('IF @@TRANCOUNT > 0 ROLLBACK TRAN').do
    rescue StandardError
      nil
    end

    def label(target)
      [target.host, target.database, target.schema, target.table].join('.')
    end

    def quote(value)
      "[#{value.to_s.gsub(']', ']]')}]"
    end
  end
end
