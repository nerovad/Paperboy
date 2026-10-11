# frozen_string_literal: true

require 'csv'
require 'minitest/autorun'
require 'tmpdir'
require_relative '../../script/ruby/data_runner/helpers/bcp_character_file'

ENV['DATARUNNER_INBOX'] ||= File.join(Dir.tmpdir, 'paperboy-bcp-character-test')
require_relative '../../script/ruby/data_runner/commands/use_dsl'

class BcpCharacterFileTest < Minitest::Test
  def test_comma_quote_and_newline_stay_one_field
    cfg = {
      header: [
        ['Note', 'Note', 'varchar(100)', 'NULL', nil],
        ['Amount', 'Amount', 'bigint', 'NULL', nil]
      ]
    }
    note = "a, \"b\"\nc"
    Dir.mktmpdir do |directory|
      source = File.join(directory, 'source.csv')
      applied = File.join(directory, 'applied.csv')
      CSV.open(source, 'w') do |csv|
        csv << %w[Note Amount]
        csv << [note, '$1,234']
        csv << ['', '']
      end

      assert_equal :applied, apply_mapping(cfg, source, applied, dsl_name: 'Sample')
      rows = character_rows(applied)

      assert_equal [%w[Note Amount], [note, '1234'], ['', '']], rows
    end
  end

  def test_terminator_in_a_field_names_the_dsl_and_column
    cfg = { header: [['Note', 'Note', 'varchar(20)', 'NULL', nil]] }
    Dir.mktmpdir do |directory|
      source = File.join(directory, 'source.csv')
      applied = File.join(directory, 'applied.csv')
      CSV.open(source, 'w') { |csv| csv << ['Note'] << ["bad#{BcpCharacterFile::FIELD}value"] }

      error = assert_raises(BcpCharacterFile::TerminatorError) do
        apply_mapping(cfg, source, applied, dsl_name: 'Sample')
      end

      assert_equal 'Sample: column Note contains a bcp field or row terminator', error.message
    end
  end

  def test_pass_path_writes_a_character_file_instead_of_copying_csv
    Dir.mktmpdir do |directory|
      source = File.join(directory, 'source.csv')
      applied = File.join(directory, 'applied.csv')
      CSV.open(source, 'w') { |csv| csv << ['Note'] << ["a, \"b\"\nc"] }

      write_unmapped_character_file(source, applied, 'Sample')

      assert_equal [['Note'], ["a, \"b\"\nc"]], character_rows(applied)
      assert_includes File.binread(applied), "\x1E".b
    end
  end

  private

  def character_rows(path)
    rows = []
    BcpCharacterFile.each_row(path) { |row| rows << row }
    rows
  end
end
