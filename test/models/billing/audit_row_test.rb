# frozen_string_literal: true

require 'test_helper'

module Billing
  class AuditRowTest < ActiveSupport::TestCase
    test 'marks invalid columns without changing their display order' do
      row = AuditRow.new({ 'TYPE' => 'GPH', 'CUNIT' => 'BAD' }, invalid_columns: ['cunit'])

      assert_equal %w[TYPE CUNIT], row.columns
      assert_not row.cells.first.invalid
      assert row.cells.last.invalid
    end
  end
end
