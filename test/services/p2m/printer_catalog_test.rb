# frozen_string_literal: true

require 'test_helper'

module P2m
  class PrinterCatalogTest < ActiveSupport::TestCase
    test 'groups GSABSS queues by printer' do
      rows = [
        { 'printer' => 'Printer One', 'queue' => 'Queue A' },
        { 'printer' => 'Printer One', 'queue' => 'Queue B' },
        { 'printer' => 'Printer Two', 'queue' => 'Queue C' }
      ]
      connection = fake_connection(rows)

      GsabssBase.stub(:connection, connection) do
        assert_equal({
                       'Printer One' => ['Queue A', 'Queue B'],
                       'Printer Two' => ['Queue C']
                     }, PrinterCatalog.new.call)
      end

      assert_match 'FROM dbo.printers', connection.verify
      assert_match 'dbo.printer_queues', connection.verify
    end

    private

    def fake_connection(rows)
      query = nil
      Object.new.tap do |object|
        object.define_singleton_method(:exec_query) do |sql|
          query = sql
          rows
        end
        object.define_singleton_method(:verify) { query }
      end
    end
  end
end
