# frozen_string_literal: true

module P2m
  class QualityControl
    SOURCES = [
      { label: 'GSABSS Companions', database: 'GSABSS', table: 'companions', job: 'budget_1_job_id' },
      { label: 'GSABSS Daily Presorts', database: 'GSABSS', table: 'daily_presorts', job: 'flduserdefined9' },
      { label: 'GSABSS Move Results', database: 'GSABSS', table: 'move_results', job: 'USER_DEFINED_9' },
      { label: 'GSAP2M Companion', database: 'GSAP2M', table: 'Companion', job: 'budget_1_job_id' },
      { label: 'GSAP2M Daily Presorts', database: 'GSAP2M', table: 'DailyPresort', job: 'flduserdefined09' },
      { label: 'GSAP2M Move Results', database: 'GSAP2M', table: 'MoveResults', job: 'USER_DEFINED_9' }
    ].freeze
    DETAIL_SOURCES = SOURCES.select { |source| source.fetch(:database) == 'GSABSS' }.freeze

    class << self
      def oms_rows(start_date:, end_date:)
        source = SOURCES.find { |candidate| candidate.fetch(:table) == 'companions' }
        sql = 'SELECT omsnumber, MAX(print_or_send_time) AS qc_date ' \
              "FROM #{qualified_name(source)} " \
              "WHERE print_or_send_time >= #{quote_date(start_date)} " \
              "AND print_or_send_time < #{quote_date(end_date + 1)} " \
              'GROUP BY omsnumber'
        connection.select_all(sql).to_a.sort_by { |row| row['omsnumber'].to_i }
      end

      def details(oms_number:)
        grouped = DETAIL_SOURCES.group_by { |source| source.fetch(:database) }.transform_values do |sources|
          sources.map { |source| grouped_rows(source, oms_number) }
        end
        upload = OmsUpload.where(oms_number: oms_number).order(imported_at: :desc).first

        all_rows = grouped.values.flatten
        {
          oms_number: oms_number,
          upload: upload,
          databases: grouped.transform_values { |rows| database_result(rows, all_rows) }
        }
      end

      private

      def connection = GsabssBase.connection

      def qualified_name(source)
        [source.fetch(:database), 'dbo', source.fetch(:table)].map { |part| connection.quote_column_name(part) }.join('.')
      end

      def quote_date(date)
        connection.quote(date.iso8601)
      end

      def grouped_rows(source, oms_number)
        sql = "SELECT #{connection.quote_column_name(source.fetch(:job))} AS job_number, COUNT(*) AS row_count " \
              "FROM #{qualified_name(source)} WHERE omsnumber = #{connection.quote(oms_number)} " \
              "GROUP BY #{connection.quote_column_name(source.fetch(:job))}"
        connection.select_all(sql).to_a.to_h do |row|
          [row['job_number']&.to_s, { source: source.fetch(:label), row_count: row['row_count'].to_i }]
        end
      end

      def database_result(rows, all_rows)
        jobs = all_rows.flat_map(&:keys).compact.map(&:to_s).uniq.sort
        totals = rows.map { |result| result.values.sum { |value| value[:row_count] } }
        all_totals = all_rows.map { |result| result.values.sum { |value| value[:row_count] } }
        { totals: totals, match: all_totals.uniq.one?, jobs: jobs.map { |job| job_result(job, rows, all_rows) } }
      end

      def job_result(job, rows, all_rows)
        values = rows.map { |result| result.fetch(job, zero_result) }
        all_values = all_rows.map { |result| result.fetch(job, zero_result) }
        { job_number: job, sources: values, match: all_values.map { |value| value[:row_count] }.uniq.one? }
      end

      def zero_result = { source: nil, row_count: nil }
    end
  end
end
