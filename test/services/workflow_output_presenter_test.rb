# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class WorkflowOutputPresenterTest < ActiveSupport::TestCase
  test "presents CSV as headers and rows" do
    with_file("sample.csv", "name,value\nAlpha,1\nBeta,2\n") do |path|
      output = WorkflowOutputPresenter.new(path)

      assert_equal "csv", output.kind
      assert_equal %w[name value], output.headers
      assert_equal [ %w[Alpha 1], %w[Beta 2] ], output.rows
      assert_not output.truncated?
    end
  end

  test "presents SQL as browser-safe text" do
    with_file("sample.sql", "SELECT * FROM widgets;\n") do |path|
      output = WorkflowOutputPresenter.new(path)

      assert_equal "sql", output.kind
      assert_equal "SELECT * FROM widgets;\n", output.content
    end
  end

  test "uses DSL header row for XLSX and omits the report banner" do
    sheet = Struct.new(:last_row) do
      def row(number)
        {
          1 => [ "<html><b>COUNTY OF VENTURA</b></html>", nil ],
          7 => [ "Fiscal Year", "Department" ],
          8 => [ 2026, "GSA" ]
        }.fetch(number, [ nil, nil ])
      end
    end.new(8)
    workbook = Struct.new(:worksheet) do
      def sheet(_index)
        worksheet
      end
    end.new(sheet)
    spreadsheet = Object.new
    spreadsheet.define_singleton_method(:open) { |_path, extension:| workbook if extension == :xlsx }

    output = WorkflowOutputPresenter.new(Pathname("units.xlsx"), header_row: 6, spreadsheet: spreadsheet)

    assert_equal [ "Fiscal Year", "Department" ], output.headers
    assert_equal [ [ 2026, "GSA" ] ], output.rows
  end

  private

  def with_file(name, content)
    Dir.mktmpdir do |directory|
      path = Pathname(directory).join(name)
      path.write(content)
      yield path
    end
  end
end
