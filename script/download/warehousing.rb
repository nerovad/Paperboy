#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'date'
require 'fileutils'
require 'nokogiri'
require 'stringio'
require 'zip'

require_relative '../constants/workflow_paths'

# Technical overview
#
# This script assembles the warehousing TC60 workbook extracts into a single
# `01_Download/warehousing.csv` file for the DataRunner pipeline. It is meant
# to run as a `source.strategy: :script` download step, with one argument:
# `ALL` to scan every accounting period folder or `APNN` to scan one period.
#
# Workflow:
# - Resolve the configured AP folders under SEARCH_DIR.
# - Find Excel workbooks whose names start with a known service category.
# - Exclude temporary, copied, and database workbooks.
# - Require a trailing `-vNN.xlsx` version and select the highest version per
#   category/period/name-detail group.
# - Stream workbook XML directly from each .xlsx zip, locate the sheet with the
#   expected TC60 header, and collect rows until the first blank CUNIT row.
# - Prefix each output row with the service TYPE and write the combined CSV to
#   WorkflowPaths::DOWNLOAD_DIR.
#
# File name patterns searched:
# - BM: `BM<MMYY>-Brownmail...-v<version>.xlsx` or `BM<MMYY>...-v<version>.xlsx`
# - CSB: `CSB<MMYY>...-v<version>.xlsx` or `CSBM<MMYY>...-v<version>.xlsx`
# - Other types: `TYPE<MMYY>...-v<version>.xlsx`, where TYPE is a key in
#   OUTPUTS and MMYY is the accounting period encoded in the workbook name.
#
# Assumptions:
# - Source workbooks live in the fixed FY25-26 billing share and use the AP
#   directory names listed in AP_DIRS.
# - Workbook filenames encode the service category, MMYY period, and trailing
#   version, for example `MTP0526-v2.xlsx`.
# - The data sheet has exactly the HEADER columns, in order, before the data
#   rows. Files with a changed layout fail fast instead of being guessed.
# - Excel date serials use the common 1899-12-30 base. Blank DATE cells may be
#   derived from POSTING_REF when it contains a category prefix plus MMYY.
ROOT = Pathname.pwd.expand_path
SEARCH_DIR = Pathname.new('/mnt/i/BUSINESS_SUPPORT/Billing/FY25-26').expand_path
OUTPUT_DIR = ROOT.join(WorkflowPaths::DOWNLOAD_DIR)

AP_DIRS = {
  'AP01' => 'AP01-Jul',
  'AP02' => 'AP02-Aug',
  'AP03' => 'AP03-Sep',
  'AP04' => 'AP04-Oct',
  'AP05' => 'AP05-Nov',
  'AP06' => 'AP06-Dec',
  'AP07' => 'AP07-Jan',
  'AP08' => 'AP08-Feb',
  'AP09' => 'AP09-Mar',
  'AP10' => 'AP10-Apr',
  'AP11' => 'AP11-May',
  'AP12' => 'AP12-Jun'
}.freeze

PERIOD_ARGS = ([ 'ALL' ] + AP_DIRS.keys).freeze

HEADER = %w[
  CUNIT COBJECT CACTIVITY CFUNCTION CPROGRAM CPHASE CTASK AMOUNT
  SUNIT SOBJECT SACTIVITY SFUNCTION SPROGRAM SPHASE STASK POSTING_REF
  SERVICE DATE DOC_NMBR DESCRIPTION OTHER1 OTHER2 OTHER3 QUANTITY RATE COST
].freeze

OUTPUT_HEADER = [ 'TYPE', *HEADER ].freeze

OUTPUTS = {
  'BM' => 'BM-TC60.csv',   # Brown Mail
  'CSB' => 'CSB-TC60.csv', # Stores Billing
  'MCR' => 'MCR-TC60.csv', # Mail Center Recieving
  'MNP' => 'MNP-TC60.csv', # Business Reply Mail
  'MTP' => 'MTP-TC60.csv', # Metering
  'PLT' => 'PLT-TC60.csv', # Pallet Storage
  'SCS' => 'SCS-TC60.csv', # Car Sales
  'SRC' => 'SRC-TC60.csv', # Warehouse Receiving
  'SSC' => 'SSC-TC60.csv', # Special Transactions
  'SSI' => 'SSI-TC60.csv'  # Sendsuite Shipping
}.freeze

NS = { 'm' => 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' }.freeze
VERSION_RE = /-v(\d+(?:\.\d+)?)\.xlsx\z/i
BROWNMAIL_RE = /\ABM\d{4}-Brownmail/i
EXCLUDE_WORDS = %w[copy database].freeze
INVALID_ZIP_DATE_WARNING = 'WARNING: invalid date/time in zip entry.'

def relative(path)
  Pathname.new(path).relative_path_from(SEARCH_DIR).to_s
end

def assert_search_dir!
  return if SEARCH_DIR.directory?

  raise "search directory not found: #{SEARCH_DIR}"
end

def selected_period
  arg = ARGV.fetch(0, nil)&.upcase
  return arg if ARGV.length == 1 && PERIOD_ARGS.include?(arg)

  raise "usage: #{$PROGRAM_NAME} ALL|APNN where APNN is AP01 through AP12"
end

def search_dirs(period)
  if period == 'ALL'
    dirs = AP_DIRS.values.filter_map do |dir_name|
      dir = SEARCH_DIR.join(dir_name)
      dir if dir.directory?
    end
    raise "AP folders not found under #{SEARCH_DIR}" if dirs.empty?

    dirs
  else
    dir = SEARCH_DIR.join(AP_DIRS.fetch(period))
    return [ dir ] if dir.directory?

    raise "#{period} folder not found under #{SEARCH_DIR}"
  end
end

def version_tuple(version)
  version.split('.').map(&:to_i)
end

def category_for(name)
  return 'BM' if name.match?(BROWNMAIL_RE)

  upper = name.upcase
  OUTPUTS.keys.find { |category| upper.start_with?(category) }
end

def input_paths(dir)
  dir.children.select do |path|
    path.file? && path.extname.downcase == '.xlsx' && category_for(path.basename.to_s)
  end.sort
end

def period_for(category, name)
  regex =
    case category
    when 'BM'
      /^BM(\d{4})(?:-Brownmail)?/i
    when 'CSB'
      /^CSBM?(\d{4})/i
    else
      /^#{Regexp.escape(category)}(\d{4})/i
    end
  match = name.match(regex)
  match && match[1]
end

def duplicate_name_detail(name, version_match)
  version_start = version_match.begin(0)
  prefix = name[0...version_start]
  detail = prefix.match(/-TC60-(.*)\z/)
  detail ? detail[1] : ''
end

def selected_inputs(period)
  chosen = {}
  skipped = []
  duplicate_ties = []

  search_dirs(period).each do |dir|
    input_paths(dir).each do |path|
      name = path.basename.to_s
      lower = name.downcase

      if name.start_with?('~$') || EXCLUDE_WORDS.any? { |word| lower.include?(word) }
        skipped << [ relative(path), 'excluded copy/database/lock file' ]
        next
      end

      category = category_for(name)
      next unless category

      version_match = name.match(VERSION_RE)
      unless version_match
        skipped << [ relative(path), 'no trailing vNN version' ]
        next
      end

      period = period_for(category, name)
      unless period
        skipped << [ relative(path), 'no MMYY period after prefix' ]
        next
      end

      version = version_tuple(version_match[1])
      key = [ category, period, duplicate_name_detail(name, version_match) ]
      current = chosen[key]

      if current.nil? || (version <=> current[:version]) == 1
        chosen[key] = { version: version, rel: relative(path), path: path }
      elsif version == current[:version]
        duplicate_ties << [ relative(path), "same selected version as #{current[:rel]}" ]
      end
    end
  end

  [ chosen, skipped, duplicate_ties ]
end

def xml_doc(text)
  Nokogiri::XML(text, &:noblanks)
end

def capture_invalid_zip_date_warnings
  original_stderr = $stderr
  captured_stderr = StringIO.new
  $stderr = captured_stderr
  result = yield
  [ result, captured_stderr.string.scan(INVALID_ZIP_DATE_WARNING).length ]
ensure
  $stderr = original_stderr
  if captured_stderr
    other_warnings = captured_stderr.string.lines.reject { |line| line.include?(INVALID_ZIP_DATE_WARNING) }
    other_warnings.each { |line| warn line.chomp }
  end
end

def shared_strings(zip)
  entry = zip.find_entry('xl/sharedStrings.xml')
  return [] unless entry

  strings = []
  current = nil
  capture_text = false

  Nokogiri::XML::Reader(entry.get_input_stream.read).each do |node|
    case node.node_type
    when 1
      if node.local_name == 'si'
        current = +''
      elsif node.local_name == 't' && current
        capture_text = true
      end
    when 3, 4
      current << node.value if capture_text && current
    when 15
      if node.local_name == 't'
        capture_text = false
      elsif node.local_name == 'si'
        strings << current.to_s
        current = nil
      end
    end
  end

  strings
end

def sheet_paths(zip)
  workbook = xml_doc(zip.read('xl/workbook.xml'))
  rels_doc = xml_doc(zip.read('xl/_rels/workbook.xml.rels'))
  rels = {}

  rels_doc.root.element_children.each do |rel|
    rels[rel['Id']] = rel['Target']
  end

  workbook.xpath('//m:sheets/m:sheet', NS).map do |sheet|
    target = rels.fetch(sheet['r:id'])
    path = target.start_with?('/') ? target.delete_prefix('/') : Pathname.new('xl').join(target).cleanpath.to_s
    [ sheet['name'].to_s, path ]
  end
end

def column_index(cell_ref)
  letters = cell_ref.to_s.scan(/[A-Za-z]/).join.upcase
  letters.each_char.reduce(0) { |idx, char| (idx * 26) + char.ord - 'A'.ord + 1 } - 1
end

def clean_number(text)
  return '' if text.nil?

  number = Float(text)
  number.to_i == number ? number.to_i.to_s : number.to_s
rescue ArgumentError
  text
end

def excel_date(text)
  value = Float(text)
  (Date.new(1899, 12, 30) + value).strftime('%m/%d/%y')
rescue ArgumentError, TypeError
  text.to_s
end

def date_from_posting_ref(posting_ref)
  match = posting_ref.to_s.strip.match(/\A[A-Za-z]{2,3}(\d{2})(\d{2})\z/)
  return nil unless match

  month, year = match.captures
  Date.strptime("#{month}/01/#{year}", '%m/%d/%y').strftime('%m/%d/%y')
rescue Date::Error
  nil
end

def normalize_date(row, source:, sheet_name:, row_number:)
  row[17] = excel_date(row[17])
  return unless row[17].to_s.strip.empty?

  derived_date = date_from_posting_ref(row[15])
  return unless derived_date

  row[17] = derived_date
  puts "Filled blank DATE at #{source}, sheet #{sheet_name.inspect}, row #{row_number}: POSTING_REF #{row[15].inspect} -> #{derived_date}"
end

def cell_value(type, value, strings)
  case type
  when 's'
    value.empty? ? '' : strings.fetch(value.to_i)
  when 'b'
    value == '1' ? 'TRUE' : 'FALSE'
  else
    clean_number(value)
  end
end

def sheet_rows(sheet_xml, strings)
  Enumerator.new do |yielder|
    row = nil
    row_number = nil
    cell_index = nil
    cell_type = nil
    cell_text = +''
    capture_text = false

    Nokogiri::XML::Reader(sheet_xml).each do |node|
      case node.node_type
      when 1
        case node.local_name
        when 'row'
          row = Array.new(HEADER.length, '')
          row_number = node.attribute('r').to_s
        when 'c'
          cell_index = column_index(node.attribute('r'))
          cell_type = node.attribute('t')
          cell_text = +''
        when 'v', 't'
          capture_text = !cell_index.nil?
        end
      when 3, 4
        cell_text << node.value if capture_text
      when 15
        case node.local_name
        when 'v', 't'
          capture_text = false
        when 'c'
          row[cell_index] = cell_value(cell_type, cell_text, strings) if row && cell_index&.between?(0, HEADER.length - 1)
          cell_index = nil
          cell_type = nil
          cell_text = +''
        when 'row'
          yielder << [ row, row_number ] if row
          row = nil
          row_number = nil
        end
      end
    end
  end
end

def read_rows(path)
  capture_invalid_zip_date_warnings do
    selected_sheet = nil

    Zip::File.open(path.to_s) do |zip|
      strings = shared_strings(zip)

      sheet_paths(zip).each do |sheet_name, sheet_path|
        header_seen = false
        rows = []

        sheet_rows(zip.read(sheet_path), strings).each do |row, row_number|
          unless header_seen
            header_seen = true if row == HEADER
            next
          end

          break if row[0].to_s.empty?

          normalize_date(row, source: relative(path), sheet_name: sheet_name, row_number: row_number)
          rows << row
        end

        if header_seen
          selected_sheet = [ sheet_name, rows ]
          break
        end
      end
    end

    selected_sheet || raise('expected header not found in workbook')
  end
end

def print_invalid_zip_date_summary(invalid_zip_dates)
  return if invalid_zip_dates.empty?

  puts "\nSource workbook ZIP timestamp warnings:"
  puts '  These workbooks contain invalid ZIP entry date/time metadata.'
  puts '  Data was read, but fix the source by opening each workbook in Excel,'
  puts '  saving a fresh .xlsx copy, and rerunning this script.'
  invalid_zip_dates.each do |rel, count|
    puts "  #{rel}: #{count} invalid ZIP entr#{count == 1 ? 'y' : 'ies'}"
  end
end

def build_warehousing_rows(chosen)
  warehousing_rows = []
  row_counts = {}
  sheet_names = {}
  invalid_zip_dates = {}
  errors = []

  chosen.sort.each do |(category, _period), input|
    (sheet_name, rows), invalid_zip_date_count = read_rows(input[:path])
    typed_rows = rows.map { |row| [ category, *row ] }
    warehousing_rows.concat(typed_rows)
    row_counts[input[:rel]] = rows.length
    sheet_names[input[:rel]] = sheet_name
    invalid_zip_dates[input[:rel]] = invalid_zip_date_count if invalid_zip_date_count.positive?
  rescue StandardError => e
    errors << [ input[:rel], e.message ]
  end

  [ warehousing_rows, row_counts, sheet_names, invalid_zip_dates, errors ]
end

def write_warehousing_csv(warehousing_rows)
  FileUtils.mkdir_p(OUTPUT_DIR)

  CSV.open(OUTPUT_DIR.join('warehousing.csv'), 'w', encoding: 'UTF-8') do |csv|
    csv << OUTPUT_HEADER
    warehousing_rows.each { |row| csv << row }
  end
end

def print_selected_inputs(period, chosen, row_counts, sheet_names)
  puts "Selected period: #{period}"
  puts "Selected input files: #{chosen.length}"
  chosen.sort.each do |(category, period_key), input|
    detail = "#{row_counts.fetch(input[:rel], 'ERROR')} rows"
    detail += ", sheet #{sheet_names[input[:rel]].inspect}" if sheet_names.key?(input[:rel])
    puts "  #{category} #{period_key}: #{input[:rel]} (#{detail})"
  end
end

def main
  assert_search_dir!

  period = selected_period
  chosen, skipped, duplicate_ties = selected_inputs(period)
  warehousing_rows, row_counts, sheet_names, invalid_zip_dates, errors = build_warehousing_rows(chosen)

  write_warehousing_csv(warehousing_rows)
  print_selected_inputs(period, chosen, row_counts, sheet_names)
  puts "\nCSV output:"
  puts "  csv/warehousing.csv: #{warehousing_rows.length} data rows"

  print_invalid_zip_date_summary(invalid_zip_dates)

  unless duplicate_ties.empty?
    puts "\nDuplicate same-version workbooks not selected:"
    duplicate_ties.each { |rel, reason| puts "  #{rel}: #{reason}" }
  end

  unless skipped.empty?
    puts "\nSkipped matching-prefix workbooks:"
    skipped.each { |rel, reason| puts "  #{rel}: #{reason}" }
  end

  return if errors.empty?

  warn "\nErrors:"
  errors.each { |rel, error| warn "  #{rel}: #{error}" }
  exit 1
end

main if $PROGRAM_NAME == __FILE__
