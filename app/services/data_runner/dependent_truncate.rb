# frozen_string_literal: true

module DataRunner
  # Empties dependent tables before a group refresh injects them.
  # Truncate runs first. Delete follows, children before parents, so a
  # delete_insert parent can remove rows a foreign key would otherwise keep.
  class DependentTruncate
    Target = Data.define(:name, :host, :database, :schema, :table, :dependencies)

    def self.perform(dsl_names, entries: DslCatalog.entries, connector: nil)
      new(dsl_names, entries, connector).perform
    end

    def initialize(dsl_names, entries, connector)
      @names = Array(dsl_names).map(&:to_s)
      @entries = entries
      @connector = connector
    end

    def perform
      DependentClear.apply(selected(:truncate), :truncate, @connector) +
        DependentClear.apply(DependentClear.order(selected(:delete)), :delete, @connector)
    end

    private

    def selected(action)
      @entries.flat_map { |entry| targets_for(entry, action) }
    end

    def targets_for(entry, action)
      return [] unless @names.include?(entry.key)

      dependencies = Array(entry.config[:dependency]).map(&:to_s).reject(&:empty?)
      return [] if dependencies.empty? || dependencies.any? { |name| @names.exclude?(name) }

      connections_for(entry.config, action).map { |connection| build_target(entry.key, connection, dependencies) }
    end

    def connections_for(config, action)
      raw = config[:database_connections] || config[:database_connection]
      list = raw.is_a?(Array) ? raw : [raw].compact
      list.select { |connection| mode_for(config, connection) == action }
    end

    def mode_for(config, connection)
      mode = connection.dig(:inject, :mode) || config.dig(:inject, :mode) || :truncate_insert
      { truncate_insert: :truncate, delete_insert: :delete }[mode.to_sym]
    end

    def build_target(name, connection, dependencies)
      target = Target.new(
        name: name,
        host: connection[:host].to_s.strip,
        database: connection[:database].to_s.strip,
        schema: connection[:schema].to_s.strip,
        table: connection[:table].to_s.strip,
        dependencies: dependencies
      )
      missing = %i[host database schema table].select { |part| target.public_send(part).empty? }
      raise "#{name}: dependent clear is missing #{missing.join(', ')}" if missing.any?

      target
    end
  end

  class DependentClear
    def self.order(targets)
      pending = targets.dup
      ordered = []
      while pending.any?
        ready = pending.reject { |target| pending.any? { |other| other.dependencies.include?(target.name) } }
        raise "circular dependent delete: #{pending.map(&:name).join(', ')}" if ready.empty?

        ordered.concat(ready)
        pending -= ready
      end
      ordered
    end

    def self.apply(targets, action, connector)
      new(connector).apply(targets, action)
    end

    def initialize(connector)
      @connector = connector
    end

    def apply(targets, action)
      targets.group_by(&:host).flat_map { |host, group| apply_host(host, group, action) }
    end

    private

    def apply_host(host, targets, action)
      client = open_client(host)
      targets.map { |target| apply_target(client, target, action) }
    ensure
      client&.close
    end

    def apply_target(client, target, action)
      client.execute("USE #{quote(target.database)}").do
      client.execute('BEGIN TRAN').do
      client.execute(statement(target, action)).do
      client.execute('COMMIT TRAN').do
      "[OK] #{target.name}: #{verb(action)} #{label(target)} before dependency inject"
    rescue StandardError
      rollback(client)
      raise
    end

    def statement(target, action)
      qualified = "#{quote(target.schema)}.#{quote(target.table)}"
      return "DELETE FROM #{qualified} WHERE 1 = 1" if action == :delete

      "TRUNCATE TABLE #{qualified}"
    end

    def verb(action)
      action == :delete ? 'deleted' : 'truncated'
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
