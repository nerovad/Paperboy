# frozen_string_literal: true

module P2m
  class QualityControl
    SOURCES = [
      { label: 'GSAP2M Companion', database: 'GSAP2M', table: 'Companion',
        job: 'Budget 1 - Job ID', number: 'OMSNumber', listed_at: 'Print or send time' },
      { label: 'GSAP2M Daily Presorts', database: 'GSAP2M', table: 'DailyPresort',
        job: 'flduserdefined9', number: 'omsnumber' },
      { label: 'GSAP2M Move Results', database: 'GSAP2M', table: 'MoveResults',
        job: 'USER_DEFINED_9', number: 'OMSNumber' }
    ].freeze
    DETAIL_SOURCES = SOURCES

    class << self
      def oms_rows(start_date:, end_date:)
        source = SOURCES.find { |candidate| candidate.fetch(:table) == 'Companion' }
        number = connection.quote_column_name(source.fetch(:number))
        listed_at = connection.quote_column_name(source.fetch(:listed_at))
        sql = "SELECT #{number} AS omsnumber, MAX(#{listed_at}) AS qc_date " \
              "FROM #{connection.quote_table_name(qualified_name(source))} " \
              "WHERE #{listed_at} >= #{connection.quote(start_date.iso8601)} " \
              "AND #{listed_at} < #{connection.quote((end_date + 1).iso8601)} " \
              "GROUP BY #{number}"
        connection.select_all(sql).to_a.sort_by { |row| row['omsnumber'].to_i }
      end

      def details(oms_number:)
        grouped = DETAIL_SOURCES.group_by { |source| source.fetch(:database) }.transform_values do |sources|
          sources.map { |source| grouped_rows(source, oms_number) }
        end
        upload = OmsUpload.where(oms_number: oms_number).order(imported_at: :desc).first

        {
          oms_number: oms_number,
          upload: upload,
          databases: grouped.transform_values { |rows| database_result(rows) }
        }
      end

      private

      def connection = GsabssBase.connection

      def qualified_name(source)
        [source.fetch(:database), 'dbo', source.fetch(:table)].join('.')
      end

      def grouped_rows(source, oms_number)
        number = connection.quote_column_name(source.fetch(:number))
        job = connection.quote_column_name(source.fetch(:job))
        sql = "SELECT #{job} AS job_number, COUNT(*) AS row_count " \
              "FROM #{connection.quote_table_name(qualified_name(source))} WHERE #{number} = #{connection.quote(oms_number)} " \
              "GROUP BY #{job}"
        connection.select_all(sql).to_a.to_h do |row|
          [row['job_number']&.to_s, { source: source.fetch(:label), row_count: row['row_count'].to_i }]
        end
      end

      def database_result(rows)
        jobs = rows.flat_map(&:keys).compact.map(&:to_s).uniq.sort
        totals = rows.map { |result| result.values.sum { |value| value[:row_count] } }
        { totals: totals, match: totals.uniq.one?, jobs: jobs.map { |job| job_result(job, rows) } }
      end

      def job_result(job, rows)
        values = rows.map { |result| result.fetch(job, zero_result) }
        { job_number: job, sources: values, match: values.map { |value| value[:row_count] }.uniq.one? }
      end

      def zero_result = { source: nil, row_count: nil }
    end
  end
end
