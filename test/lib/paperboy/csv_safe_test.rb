# frozen_string_literal: true

require 'test_helper'

module Paperboy
  class CsvSafeTest < ActiveSupport::TestCase
    test 'a cell that would run as a formula is prefixed with an apostrophe' do
      ['=1+1', '+SUM(A1)', '-2+3', '@cmd', "\tx", "\rx"].each do |text|
        assert_equal "'#{text}", CsvSafe.defuse(text)
      end
      assert_equal 'Acme, Inc.', CsvSafe.defuse('Acme, Inc.')
    end

    test 'only strings are defused' do
      assert_equal(-12.5, CsvSafe.defuse_cell(-12.5))
      assert_nil CsvSafe.defuse_cell(nil)
      assert_equal ["'=x", 7, nil, 'ok'], CsvSafe.defuse_row(['=x', 7, nil, 'ok'])
    end

    test 'restore undoes defuse and leaves everything else alone' do
      ['=1+1', '-note', 'plain', "'quoted"].each do |text|
        assert_equal text, CsvSafe.restore(CsvSafe.defuse(text))
      end
      assert_equal '', CsvSafe.restore(nil)
    end

    test 'RecordsCsv defuses with the shared rule' do
      assert_equal CsvSafe::FORMULA_TRIGGERS, RecordsCsv::FORMULA_TRIGGERS
      assert_equal "'=x", RecordsCsv.defuse('=x')
    end
  end
end
