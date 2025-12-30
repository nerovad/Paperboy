# app/reports/base/sql_provider.rb
module Reports
  module Base
    class SqlProvider
      def initialize(stored_proc, params)
        @stored_proc = stored_proc
        @params      = params
      end

      def fetch
        # Example output:  "@sDate='2024-01-01', @eDate='2024-01-31', @type='RM'"
        args = @params.map { |k, v| "@#{k}='#{v}'" }.join(", ")

        sql = "EXEC #{@stored_proc} #{args}"

        result = ActiveRecord::Base.connection.exec_query(sql)

        result.to_a.map(&:symbolize_keys)
      end
    end
  end
end
