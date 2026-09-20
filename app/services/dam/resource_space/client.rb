# frozen_string_literal: true

module Dam
  module ResourceSpace
    # A read-only connection to ResourceSpace's MySQL database.
    #
    # ResourceSpace is the system this library is replacing, and it is still
    # running, so nothing here ever writes. Credentials come from the host's
    # .env as RS_DB_*, the same way every other outside system Paperboy reads
    # is configured, and a missing one is an error at the point of use rather
    # than a nil that turns into an empty import.
    class Client
      class NotConfigured < StandardError; end

      # mysql2 lives in an optional bundler group, so most hosts never build
      # it. Required here rather than at boot, which is what lets a server
      # without it run everything else in the DAM quite happily.
      def self.load_driver!
        require 'mysql2'
      rescue LoadError
        raise NotConfigured, 'The mysql2 gem is not installed here. It is in the optional ' \
                             '"resourcespace" bundler group: bundle config set --local with ' \
                             'resourcespace && bundle install'
      end

      SETTINGS = { host: 'RS_DB_HOST', username: 'RS_DB_USER',
                   password: 'RS_DB_PASSWORD', database: 'RS_DB_NAME' }.freeze

      def self.configured? = SETTINGS.values.all? { |key| ENV[key].present? }

      def self.settings
        missing = SETTINGS.values.reject { |key| ENV[key].present? }
        raise NotConfigured, "ResourceSpace is not configured: #{missing.join(', ')} unset" if missing.any?

        SETTINGS.transform_values { |key| ENV.fetch(key) }
      end

      def initialize(connection: nil)
        @connection = connection
      end

      # Rows as plain hashes. Casting is left to the caller: everything here is
      # either a string or an integer, and Mysql2's date handling is one more
      # thing to reason about at four in the morning.
      def query(sql, *binds)
        connection.query(format_sql(sql, binds), symbolize_keys: false).to_a
      end

      def connection
        # No reconnect: the option is deprecated in the client, and an import
        # that loses the connection should stop and say so rather than carry
        # on against a session that has quietly restarted.
        self.class.load_driver!
        @connection ||= Mysql2::Client.new(**self.class.settings)
      end

      def close
        @connection&.close
      rescue StandardError
        nil
      end

      private

      # Binds are escaped rather than prepared: these are read queries built
      # from id lists, and a prepared statement per list length is worse.
      def format_sql(sql, binds)
        return sql if binds.empty?

        format(sql, *binds.map { |bind| quote(bind) })
      end

      def quote(value)
        case value
        when Array then value.map { |item| quote(item) }.join(', ').presence || 'NULL'
        when Integer then value.to_s
        else "'#{connection.escape(value.to_s)}'"
        end
      end
    end
  end
end
