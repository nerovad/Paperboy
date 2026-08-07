# frozen_string_literal: true

module Billing
  # Counts TC60 accounting values that are absent from their lookup tables.
  class Audit
    Check = Data.define(:key, :label, :column, :lookup_table, :lookup_column)
    Group = Data.define(:key, :label, :checks)
    Result = Data.define(:key, :label, :count)
    Detail = Data.define(:value, :count)

    GROUPS = [
      Group.new(
        key: :customer,
        label: 'Customer Accounting String',
        checks: [
          Check.new(key: :cunit, label: 'CUNIT', column: 'CUNIT',
                    lookup_table: 'units', lookup_column: 'unit_id'),
          Check.new(key: :cobject, label: 'COBJECT', column: 'COBJECT',
                    lookup_table: 'objects', lookup_column: 'object_id'),
          Check.new(key: :cactivity, label: 'CACTIVITY', column: 'CACTIVITY',
                    lookup_table: 'activities', lookup_column: 'activity_id'),
          Check.new(key: :cfunction, label: 'CFUNCTION', column: 'CFUNCTION',
                    lookup_table: 'functions', lookup_column: 'function_id'),
          Check.new(key: :cprogram, label: 'CPROGRAM', column: 'CPROGRAM',
                    lookup_table: 'programs', lookup_column: 'program_id'),
          Check.new(key: :cphase, label: 'CPHASE', column: 'CPHASE',
                    lookup_table: 'phases', lookup_column: 'phase_id'),
          Check.new(key: :ctask, label: 'CTASK', column: 'CTASK',
                    lookup_table: 'tasks', lookup_column: 'task_id')
        ].freeze
      ),
      Group.new(
        key: :service_provider,
        label: 'Service Provider Accounting String',
        checks: [
          Check.new(key: :service, label: 'SERVICE', column: 'SERVICE',
                    lookup_table: 'tc60_services', lookup_column: 'service'),
          Check.new(key: :sactivity, label: 'SACTIVITY', column: 'SACTIVITY',
                    lookup_table: 'activities', lookup_column: 'activity_id'),
          Check.new(key: :sfunction, label: 'SFUNCTION', column: 'SFUNCTION',
                    lookup_table: 'functions', lookup_column: 'function_id')
        ].freeze
      )
    ].freeze

    def initialize(period, connection: BillingBase.connection)
      @period = period
      @connection = connection
    end

    def self.find_check(key) = GROUPS.flat_map(&:checks).find { |check| check.key.to_s == key.to_s }

    def results
      counts = connection.exec_query(query).to_a.to_h do |row|
        [row.fetch('audit_key').to_sym, row.fetch('failure_count').to_i]
      end

      GROUPS.to_h do |group|
        results = group.checks.map do |check|
          Result.new(key: check.key, label: check.label, count: counts.fetch(check.key, 0))
        end
        [group, results]
      end
    end

    def details(key)
      check = self.class.find_check(key)
      raise KeyError, key unless check

      connection.exec_query(detail_query(check)).map do |row|
        Detail.new(value: row.fetch('invalid_value'), count: row.fetch('failure_count').to_i)
      end
    end

    private

    attr_reader :connection, :period

    def query
      sql = GROUPS.flat_map(&:checks).map { |check| check_query(check) }.join("\nUNION ALL\n")
      dates = GROUPS.flat_map(&:checks).flat_map { [period.start_date, period.end_date] }
      sanitize(sql, *dates)
    end

    def check_query(check)
      <<~SQL.squish
        SELECT '#{check.key}' AS audit_key, COUNT_BIG(*) AS failure_count
        FROM GSABSS.dbo.tc60 T
        WHERE NULLIF(LTRIM(RTRIM(T.#{check.column})), '') IS NOT NULL
          AND T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?)
          AND NOT EXISTS (
            SELECT 1 FROM GSABSS.dbo.#{check.lookup_table} Z
            WHERE Z.#{check.lookup_column} = T.#{check.column}
          )
      SQL
    end

    def detail_query(check)
      sql = <<~SQL.squish
        SELECT LTRIM(RTRIM(T.#{check.column})) AS invalid_value,
               COUNT_BIG(*) AS failure_count
        FROM GSABSS.dbo.tc60 T
        WHERE NULLIF(LTRIM(RTRIM(T.#{check.column})), '') IS NOT NULL
          AND T.[DATE] >= ? AND T.[DATE] < DATEADD(day, 1, ?)
          AND NOT EXISTS (
            SELECT 1 FROM GSABSS.dbo.#{check.lookup_table} Z
            WHERE Z.#{check.lookup_column} = T.#{check.column}
          )
        GROUP BY LTRIM(RTRIM(T.#{check.column}))
        ORDER BY failure_count DESC, invalid_value
      SQL
      sanitize(sql, period.start_date, period.end_date)
    end

    def sanitize(sql, *values)
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, *values])
    end
  end
end
