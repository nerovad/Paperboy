# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require_relative '../../script/ruby/data_runner/helpers/bcp_character_file'

class WorkflowOutputPresenterTest < ActiveSupport::TestCase
  test 'presents CSV as headers and rows' do
    with_file('sample.csv', "name,value\nAlpha,1\nBeta,2\n") do |path|
      output = WorkflowOutputPresenter.new(path)

      assert_equal 'csv', output.kind
      assert_equal %w[name value], output.headers
      assert_equal [%w[Alpha 1], %w[Beta 2]], output.rows
      assert_not output.truncated?
    end
  end

  test 'returns one page of a csv and the full row count' do
    body = +"name\n"
    5.times { |number| body << "Row #{number}\n" }
    with_file('paged.csv', body) do |path|
      output = WorkflowOutputPresenter.new(path, page: 2, per_page: 2)

      assert_equal 5, output.row_count
      assert_equal [['Row 2'], ['Row 3']], output.rows
      assert_not output.truncated?
      assert_not output.more?
    end
  end

  test 'caps a preview at the requested row count' do
    body = +"name\n"
    5.times { |number| body << "Row #{number}\n" }
    with_file('capped.csv', body) do |path|
      output = WorkflowOutputPresenter.new(path, max_rows: 3)

      assert_equal 3, output.max_rows
      assert_equal [['Row 0'], ['Row 1'], ['Row 2']], output.rows
      assert output.truncated?
    end
  end

  test 'normalizes ragged CSV rows for datatables' do
    with_file('ragged.csv', "name,value\nAlpha,1,extra\nBeta\n") do |path|
      output = WorkflowOutputPresenter.new(path)

      assert_equal ['name', 'value', 'Column 3'], output.headers
      assert_equal [%w[Alpha 1 extra], ['Beta', nil, nil]], output.rows
    end
  end

  test 'presents SQL as browser-safe text' do
    with_file('sample.sql', "SELECT * FROM widgets;\n") do |path|
      output = WorkflowOutputPresenter.new(path)

      assert_equal 'sql', output.kind
      assert_equal "SELECT * FROM widgets;\n", output.content
    end
  end

  test 'uses DSL header row for XLSX and omits the report banner' do
    sheet = Struct.new(:last_row) do
      def row(number)
        {
          1 => ['<html><b>COUNTY OF VENTURA</b></html>', nil],
          7 => ['Fiscal Year', 'Department'],
          8 => [2026, 'GSA']
        }.fetch(number, [nil, nil])
      end
    end.new(8)
    workbook = Struct.new(:worksheet) do
      def sheet(_index)
        worksheet
      end
    end.new(sheet)
    spreadsheet = Object.new
    spreadsheet.define_singleton_method(:open) { |_path, extension:| workbook if extension == :xlsx }

    output = WorkflowOutputPresenter.new(Pathname('units.xlsx'), header_row: 6, spreadsheet: spreadsheet)

    assert_equal ['Fiscal Year', 'Department'], output.headers
    assert_equal [[2026, 'GSA']], output.rows
  end

  test 'normalizes ragged XLSX rows for datatables' do
    sheet = Struct.new(:last_row) do
      def row(number)
        {
          1 => %w[Name Value],
          2 => ['Alpha', 1, 'extra'],
          3 => ['Beta']
        }.fetch(number, [])
      end
    end.new(3)
    workbook = Struct.new(:worksheet) do
      def sheet(_index)
        worksheet
      end
    end.new(sheet)
    spreadsheet = Object.new
    spreadsheet.define_singleton_method(:open) { |_path, extension:| workbook if extension == :xlsx }

    output = WorkflowOutputPresenter.new(Pathname('ragged.xlsx'), spreadsheet: spreadsheet)

    assert_equal ['Name', 'Value', 'Column 3'], output.headers
    assert_equal [['Alpha', 1, 'extra'], ['Beta', nil, nil]], output.rows
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

class WorkflowOutputCsvPageTest < ActiveSupport::TestCase
  test 'pages a comma separated file that sits in the applied directory' do
    body = +"id\n"
    3.times { |number| body << "#{number}\n" }
    Dir.mktmpdir do |directory|
      applied = Pathname(directory).join('05_DSL_Applied')
      applied.mkpath
      path = applied.join('employees.csv')
      path.write(body)

      output = WorkflowOutputPresenter.new(path, page: 1, per_page: 2)

      assert_equal [['0'], ['1']], output.rows
      assert_equal 3, output.row_count
      assert_not output.more?
    end
  end

  test 'reads an applied bcp file on its field and row terminators' do
    note = "a, \"b\"\nc"
    Dir.mktmpdir do |directory|
      applied = Pathname(directory).join('05_DSL_Applied')
      applied.mkpath
      path = applied.join('sample.csv')
      File.open(path, 'wb') do |io|
        BcpCharacterFile.write_row(io, ['Note'], dsl: 'Sample', columns: ['Note'])
        BcpCharacterFile.write_row(io, [note], dsl: 'Sample', columns: ['Note'])
      end

      output = WorkflowOutputPresenter.new(path)

      assert_equal ['Note'], output.headers
      assert_equal [[note]], output.rows
    end
  end

  test 'stops a large csv after this page and one extra row' do
    csv_file do |path|
      WorkflowOutputPresenter.stub(:exact_csv_count?, false) do
        output = WorkflowOutputPresenter.new(path, page: 1, per_page: 2)

        assert_nil output.row_count
        assert output.more?
        assert_equal [['Row 0'], ['Row 1']], output.rows
        assert_equal 1, output.page_from
        assert_equal 2, output.page_to
      end
    end
  end

  test 'counts a large csv when the requested page reaches the end' do
    csv_file do |path|
      WorkflowOutputPresenter.stub(:exact_csv_count?, false) do
        output = WorkflowOutputPresenter.new(path, page: 3, per_page: 2)

        assert_equal 5, output.row_count
        assert_not output.more?
        assert_equal [['Row 4']], output.rows
        assert_equal 5, output.page_from
        assert_equal 5, output.page_to
      end
    end
  end

  private

  def csv_file
    body = +"name\n"
    5.times { |number| body << "Row #{number}\n" }
    Dir.mktmpdir do |directory|
      path = Pathname(directory).join('large.csv')
      path.write(body)
      yield path
    end
  end
end
