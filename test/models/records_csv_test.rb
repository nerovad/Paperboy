# frozen_string_literal: true

require 'test_helper'

class RecordsCsvTest < ActiveSupport::TestCase
  View = Struct.new(:table, :columns, :rows, keyword_init: true)

  def column(id, label: id.titleize)
    TableColumns::Column.new(id: id, label: label, sort_key: id, kind: :text,
                             value: ->(row) { row[id] })
  end

  def pcard_table = RegistryTable.find('pcard')

  test 'writes a header of column labels and a row per record, in view order' do
    view = View.new(table: pcard_table,
                    columns: [column('last_name', label: 'Last'), column('agency')],
                    rows: [{ 'last_name' => 'Smith', 'agency' => 'GSA' },
                           { 'last_name' => 'Patel', 'agency' => 'HCA' }])

    assert_equal "Last,Agency\nSmith,GSA\nPatel,HCA\n", RecordsCsv.generate(view)
  end

  test 'leaves encrypted attributes out even when declared as a column' do
    view = View.new(table: pcard_table,
                    columns: [column('last_name'), column('card_number')],
                    rows: [{ 'last_name' => 'Smith', 'card_number' => '4111111111111111' }])

    csv = RecordsCsv.generate(view)

    assert_not_includes csv, '4111'
    assert_not_includes csv, 'Card Number'
  end

  test 'formats values as spreadsheet text' do
    col = column('value')
    at = Time.utc(2026, 9, 15, 15, 30)

    assert_equal '', RecordsCsv.cell(col, { 'value' => nil })
    assert_equal 'Yes', RecordsCsv.cell(col, { 'value' => true })
    assert_equal 'No', RecordsCsv.cell(col, { 'value' => false })
    assert_equal '2026-09-15', RecordsCsv.cell(col, { 'value' => Date.new(2026, 9, 15) })
    assert_equal '2026-09-15 08:30', RecordsCsv.cell(col, { 'value' => at })
    assert_equal '12.5', RecordsCsv.cell(col, { 'value' => BigDecimal('12.50') })
    assert_equal '-3', RecordsCsv.cell(col, { 'value' => -3 })
  end

  test 'defuses text a spreadsheet would run as a formula' do
    col = column('value')

    assert_equal "'=HYPERLINK(\"x\")", RecordsCsv.cell(col, { 'value' => '=HYPERLINK("x")' })
    assert_equal "'+1", RecordsCsv.cell(col, { 'value' => '+1' })
    assert_equal "'@SUM(A1)", RecordsCsv.cell(col, { 'value' => '@SUM(A1)' })
    assert_equal 'Ford', RecordsCsv.cell(col, { 'value' => 'Ford' })
  end

  test 'names the file after the table and the day' do
    assert_equal 'pcard-2026-09-15.csv', RecordsCsv.filename(pcard_table, Date.new(2026, 9, 15))
  end
end
