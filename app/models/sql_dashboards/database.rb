# frozen_string_literal: true

module SqlDashboards
  # A database typed SQL may run against, and the read-only connection it
  # runs on.
  #
  # The connection is the application's own (same server, same database for
  # this environment) with the login swapped for the read-only one named by
  # SQL_DASHBOARDS_USERNAME and SQL_DASHBOARDS_PASSWORD. Without that login
  # nothing runs: the application's login can write, and typed SQL must not.
  class Database
    class NotConfigured < StandardError; end

    DEFAULT_TIMEOUT = 30
    DEFAULT_ROW_LIMIT = 2000

    # The database a query starts in. Billing has no entry of its own: the
    # application's billing pool is a second connection to GSABSS.
    ALL = {
      'paperboy' => { label: 'Paperboy', source: 'ApplicationRecord',
                      connection: 'SqlDashboards::PaperboyConnection' },
      'gsabss' => { label: 'GSABSS (org and billing)', source: 'GsabssBase',
                    connection: 'SqlDashboards::GsabssConnection' }
    }.freeze

    attr_reader :key

    class << self
      def keys = ALL.keys

      def options = ALL.map { |key, entry| [entry[:label], key] }

      def find(key)
        new(key.to_s) if ALL.key?(key.to_s)
      end

      def configured? = credentials.present?

      # The read-only login, or nil when this server has not been given one.
      def credentials
        username = ENV['SQL_DASHBOARDS_USERNAME'].to_s.strip
        password = ENV['SQL_DASHBOARDS_PASSWORD'].to_s
        { username: username, password: password } if username.present? && password.present?
      end

      # Seconds a statement may run before SQL Server is told to cancel it.
      def timeout
        positive(ENV.fetch('SQL_DASHBOARDS_TIMEOUT', nil)) || DEFAULT_TIMEOUT
      end

      # Rows kept from one run. Anything past it is dropped and said so.
      def row_limit
        positive(ENV.fetch('SQL_DASHBOARDS_ROW_LIMIT', nil)) || DEFAULT_ROW_LIMIT
      end

      # The source connection's settings under the read-only login. The
      # adapter reads +timeout+ in milliseconds and treats under a second as
      # no timeout at all.
      def read_only_config(source)
        source.connection_db_config.configuration_hash.merge(credentials, timeout: timeout * 1000)
      end

      private

      def positive(value)
        number = value.to_i
        number if number.positive?
      end
    end

    def initialize(key)
      @key = key
    end

    def label = ALL.fetch(key)[:label]

    def pool
      raise NotConfigured, 'SQL Dashboards has no read-only login on this server.' unless self.class.configured?

      ALL.fetch(key)[:connection].constantize.connection_pool
    end
  end
end
