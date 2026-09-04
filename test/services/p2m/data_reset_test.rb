# frozen_string_literal: true

require 'test_helper'

module P2m
  class DataResetTest < ActiveSupport::TestCase
    test 'removes configured files and clears GSABSS tables' do
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory)
        staging = root.join('staging').tap(&:mkpath)
        staging.join('nested').mkpath
        staging.join('nested/output.pdf').write('pdf')
        report = root.join('p2m_oms_backfill_report.json').tap { |path| path.write('{}') }
        connection = RecordingConnection.new

        results = DataReset.new(
          paths: { 'P2M_STAGING' => staging }, report_path: report, connection: connection
        ).call

        assert_empty staging.children
        refute report.exist?
        assert_equal ['nested/output.pdf'], results.first.fetch('items')
        assert_equal ['p2m_oms_backfill_report.json'], results.second.fetch('items')
        assert_equal 6, connection.executed.size
        assert_includes connection.executed, 'TRUNCATE TABLE GSABSS.dbo.companions'
        assert_includes connection.executed, 'DELETE FROM GSABSS.dbo.p2m_oms_uploads'
      end
    end

    test 'previews files and row counts without removing data' do
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory)
        staging = root.join('staging').tap(&:mkpath)
        staging.join('output.pdf').write('pdf')
        report = root.join('p2m_oms_backfill_report.json').tap { |path| path.write('{}') }
        connection = RecordingConnection.new

        results = DataReset.new(
          paths: { 'P2M_STAGING' => staging }, report_path: report, connection: connection
        ).preview

        assert staging.join('output.pdf').exist?
        assert report.exist?
        assert_equal ['output.pdf'], results.first.fetch('items')
        assert_equal 'Rows found', results.last.fetch('action')
        assert_empty connection.executed
      end
    end

    class RecordingConnection
      attr_reader :executed

      def initialize
        @executed = []
      end

      def select_value(_query)
        2
      end

      def execute(query)
        executed << query
      end
    end
  end
end
