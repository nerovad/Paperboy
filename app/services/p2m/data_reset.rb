# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require_relative 'paths'

module P2m
  class DataReset # rubocop:disable Metrics/ClassLength
    DATABASE_RESETS = [
      ['GSABSS.dbo.companions',
       'SELECT COUNT(*) FROM GSABSS.dbo.companions',
       'TRUNCATE TABLE GSABSS.dbo.companions', 'Rows truncated'],
      ['GSABSS.dbo.daily_presorts',
       'SELECT COUNT(*) FROM GSABSS.dbo.daily_presorts',
       'TRUNCATE TABLE GSABSS.dbo.daily_presorts', 'Rows truncated'],
      ['GSABSS.dbo.move_results',
       'SELECT COUNT(*) FROM GSABSS.dbo.move_results',
       'TRUNCATE TABLE GSABSS.dbo.move_results', 'Rows truncated'],
      ['GSABSS.dbo.p2m_oms_upload_files',
       'SELECT COUNT(*) FROM GSABSS.dbo.p2m_oms_upload_files',
       'TRUNCATE TABLE GSABSS.dbo.p2m_oms_upload_files', 'Rows truncated'],
      ['GSABSS.dbo.p2m_oms_upload_findings',
       'SELECT COUNT(*) FROM GSABSS.dbo.p2m_oms_upload_findings',
       'TRUNCATE TABLE GSABSS.dbo.p2m_oms_upload_findings', 'Rows truncated'],
      ['GSABSS.dbo.p2m_oms_uploads',
       'SELECT COUNT(*) FROM GSABSS.dbo.p2m_oms_uploads',
       'DELETE FROM GSABSS.dbo.p2m_oms_uploads', 'Rows deleted']
    ].freeze

    def initialize(paths: nil, report_path: nil, connection: GsabssBase.connection)
      @paths = paths || configured_paths
      @report_path = Pathname.new(report_path || default_report_path).expand_path
      @connection = connection
    end

    def call
      paths.map { |label, path| reset_directory(label, path) } +
        [remove_report] + database_results
    end

    def preview
      paths.map { |label, path| inspect_directory(label, path) } +
        [inspect_report] + database_results(reset: false)
    end

    private

    attr_reader :paths, :report_path, :connection

    def configured_paths
      {
        'P2M_SHIPPING_STATION' => Paths::SHIPPING_STATION_PATH,
        'P2M_STAGING' => Paths::STAGING_PATH,
        'P2M_TEMPORARY_OUTPUT' => Paths::DATA_RUNNER_ROOT.join(Paths::TEMPORARY_OUTPUT),
        'P2M_PROCESSED' => Paths::PROCESSED_PATH,
        'P2M_PRINTERS' => Paths::PRINTERS_PATH
      }
    end

    def default_report_path
      Paths::DATA_RUNNER_ROOT.join('p2m_oms_backfill_report.json')
    end

    def reset_directory(label, configured_path)
      path = Pathname.new(configured_path).expand_path
      validate_reset_path!(path)
      items = removable_files(path)
      path.children.each { |child| FileUtils.rm_rf(child) } if path.directory?
      result(label, 'Files removed', items)
    rescue SystemCallError, ArgumentError => e
      result(label, 'Error', [e.message], error: true)
    end

    def inspect_directory(label, configured_path)
      path = Pathname.new(configured_path).expand_path
      validate_reset_path!(path)
      result(label, 'Files found', removable_files(path))
    rescue SystemCallError, ArgumentError => e
      result(label, 'Error', [e.message], error: true)
    end

    def remove_report
      items = report_path.file? ? [report_path.basename.to_s] : []
      FileUtils.rm_f(report_path)
      result('p2m_oms_backfill_report.json', 'Files removed', items)
    rescue SystemCallError => e
      result('p2m_oms_backfill_report.json', 'Error', [e.message], error: true)
    end

    def inspect_report
      items = report_path.file? ? [report_path.basename.to_s] : []
      result('p2m_oms_backfill_report.json', 'Files found', items)
    rescue SystemCallError => e
      result('p2m_oms_backfill_report.json', 'Error', [e.message], error: true)
    end

    def removable_files(path)
      return [] unless path.directory?

      Dir.glob(path.join('**/*'), File::FNM_DOTMATCH).filter_map do |name|
        candidate = Pathname.new(name)
        next if %w[. ..].include?(candidate.basename.to_s) || candidate.directory?

        candidate.relative_path_from(path).to_s
      end.sort
    end

    def validate_reset_path!(path)
      protected_paths = [Paths::DATA_RUNNER_ROOT.expand_path, Pathname.new(Dir.home).expand_path,
                         Rails.root.expand_path]
      invalid = path.root? || protected_paths.include?(path)
      raise ArgumentError, "unsafe reset path: #{path}" if invalid
    end

    def database_results(reset: true)
      DATABASE_RESETS.map { |definition| reset_table(*definition, reset: reset) }
    end

    def reset_table(table, count_sql, reset_sql, action, reset:)
      count = connection.select_value(count_sql).to_i
      connection.execute(reset_sql) if reset
      displayed_action = reset ? action : 'Rows found'
      result(table, displayed_action, ["#{count} #{'row'.pluralize(count)}"], count: count)
    rescue ActiveRecord::ActiveRecordError => e
      result(table, 'Error', [e.message], error: true)
    end

    def result(target, action, items, error: false, count: items.size)
      { 'target' => target, 'action' => action, 'items' => items, 'count' => count, 'error' => error }
    end
  end # rubocop:enable Metrics/ClassLength
end
