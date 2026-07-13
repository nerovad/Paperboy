# frozen_string_literal: true

# app/reports/base/sql_provider.rb
module Base
  class SqlProvider
    SQL_IDENTIFIER = /\A[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*){0,2}\z/
    SQL_PARAMETER = /\A[A-Za-z_][A-Za-z0-9_]*\z/

    def initialize(stored_proc, params)
      @stored_proc = stored_proc
      @params      = params
    end

    def fetch
      stored_proc = validated_identifier(@stored_proc)
      args = @params.keys.map { |key| "@#{validated_parameter(key)} = ?" }.join(', ')
      sql = ['EXEC', stored_proc, args.presence].compact.join(' ')
      binds = @params.map do |key, value|
        ActiveRecord::Relation::QueryAttribute.new(
          key.to_s,
          value,
          ActiveRecord::Type::Value.new
        )
      end

      result = ActiveRecord::Base.connection.exec_query(sql, 'Report SQL', binds)

      result.to_a.map do |row|
        row.transform_keys { |k| k.to_s.downcase }
      end
    end

    private

    def validated_identifier(value)
      identifier = value.to_s
      raise ArgumentError, 'Invalid stored procedure name' unless identifier.match?(SQL_IDENTIFIER)

      identifier
    end

    def validated_parameter(value)
      parameter = value.to_s
      raise ArgumentError, 'Invalid stored procedure parameter' unless parameter.match?(SQL_PARAMETER)

      parameter
    end
  end
end
