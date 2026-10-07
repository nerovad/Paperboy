# frozen_string_literal: true

require 'test_helper'

module P2m
  class QualityControlTest < ActiveSupport::TestCase
    test 'lists OMS numbers from GSAP2M Companion print or send time' do
      connection = QueryConnection.new
      QualityControl.stub(:connection, connection) do
        rows = QualityControl.oms_rows(start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 7))

        assert_equal [{ 'omsnumber' => '52543073', 'qc_date' => '2026-10-05T07:14:00' }], rows
      end

      sql = connection.statements.join("\n")
      assert_includes sql, '[GSAP2M].[dbo].[Companion]'
      assert_includes sql, '[Print or send time]'
      assert_includes sql, '[OMSNumber]'
      assert_not_includes sql, 'GSABSS'
      assert_not_includes sql, 'print_or_send_time'
    end

    test 'match is the three GSAP2M totals and ignores printed mailed and UAA' do
      create_upload(input_record_count: 9, mailed_record_count: 2, non_mailed_record_count: 7)
      connection = QueryConnection.new('Companion' => { 'RSPBLL' => 4 },
                                       'DailyPresort' => { 'RSPBLL' => 4 },
                                       'MoveResults' => { 'RSPBLL' => 4 })

      result = QualityControl.stub(:connection, connection) do
        QualityControl.details(oms_number: oms_number)
      end

      database = result.fetch(:databases).fetch('GSAP2M')
      assert_equal [4, 4, 4], database.fetch(:totals)
      assert database.fetch(:match)
      assert_equal 9, result.fetch(:upload).input_record_count
      assert_equal 2, result.fetch(:upload).mailed_record_count
      assert_equal 7, result.fetch(:upload).non_mailed_record_count
      assert_not_includes connection.statements.join("\n"), 'GSABSS'
    end

    test 'mismatch stays on the GSAP2M totals when one table differs' do
      connection = QueryConnection.new('Companion' => { 'RSPBLL' => 4, 'OTHER' => 1 },
                                       'DailyPresort' => { 'RSPBLL' => 4, 'OTHER' => 1 },
                                       'MoveResults' => { 'RSPBLL' => 4, 'OTHER' => 2 })

      result = QualityControl.stub(:connection, connection) do
        QualityControl.details(oms_number: oms_number)
      end

      database = result.fetch(:databases).fetch('GSAP2M')
      assert_equal [5, 5, 6], database.fetch(:totals)
      assert_not database.fetch(:match)
      jobs = database.fetch(:jobs).to_h { |job| [job.fetch(:job_number), job.fetch(:match)] }
      assert_equal({ 'OTHER' => false, 'RSPBLL' => true }, jobs)
      assert_equal ['GSAP2M'], result.fetch(:databases).keys
    end

    private

    def create_upload(**counts)
      OmsUpload.create!(oms_number: oms_number, mailer_date: Date.new(2099, 3, 2), status: 'ready',
                        validation_status: 'passed', import_status: 'imported', archive_status: 'queued',
                        **counts)
    end

    def oms_number
      @oms_number ||= format('5180%04d', Process.pid % 10_000)
    end
  end

  class QueryConnection
    attr_reader :statements

    def initialize(counts = {})
      @counts = counts
      @statements = []
    end

    def quote_column_name(part) = "[#{part}]"
    def quote(value) = "'#{value}'"

    def select_all(sql)
      @statements << sql
      return [{ 'omsnumber' => '52543073', 'qc_date' => '2026-10-05T07:14:00' }] if sql.include?('MAX(')

      table = @counts.keys.find { |name| sql.include?(".#{quote_column_name(name)}]") || sql.include?("[#{name}]") }
      @counts.fetch(table).map { |job, count| { 'job_number' => job, 'row_count' => count } }
    end
  end
end
