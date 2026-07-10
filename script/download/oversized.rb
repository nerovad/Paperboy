#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'pathname'
require 'rexml/document'

require_relative '../commands/dsl_map'
require_relative '../helpers/etl_helpers'
require_relative '../constants/workflow_paths'

ROOT = Pathname.new(__dir__).parent.expand_path
CFG = DSL_MAP.fetch('Oversized')
SRC = EtlHelpers.source(CFG)
XML_CFG = CFG.fetch(:xml, {})
DOWNLOAD_DIR = Pathname.new(WorkflowPaths::DOWNLOAD_DIR)
OUTPUT_PATH = DOWNLOAD_DIR.join(EtlHelpers.source_local(CFG).to_s)
DEFAULT_BU_FILE = ROOT.join('download/oversized_business_units.csv').expand_path
OUTPUT_HEADER = %w[Date ProfileType BU Length Width Type FilePath FileName].freeze
XML_DIR = '/mnt/i/BUSINESS_SUPPORT/Scan\ Center/Oversized\ Scan\ Data/Monthly\ Exports/'
XML_FILE_PATTERN = 'ovs-*.xml'

def xml_source_dir
  Pathname.new(XML_DIR.gsub('\ ', ' ')).expand_path(ROOT)
end

def configured_location
  location = EtlHelpers.source_location(CFG).to_s
  return nil if location.strip.empty?

  Pathname.new(location).expand_path(ROOT)
end

def business_units_path
  env_path = ENV.fetch('OVERSIZED_BUSINESS_UNITS', nil)
  return Pathname.new(env_path).expand_path(ROOT) unless env_path.to_s.strip.empty?

  configured = XML_CFG[:business_units]
  return DEFAULT_BU_FILE if configured.nil? || configured.to_s.strip.empty?

  Pathname.new(configured.to_s).expand_path(ROOT)
end

def load_business_units(path)
  map = {}
  CSV.foreach(path, headers: true, encoding: 'bom|utf-8') do |row|
    name = row['name'].to_s
    next if name.strip.empty?

    map[name] = {
      alias: row['alias'].to_s,
      code: row['code'].to_s
    }
  end
  map
end

def convert_to_inches(value_str, unit)
  return 0.0 unless unit.to_s == '1/1200"'

  value_str.to_f / 1200.0
end

def determine_scan_type(length, width)
  return 'RS' if (length < 11.6 && width < 17.6) || (length < 17.6 && width < 11.6)

  'OVS'
end

def split_date(dt_str)
  dt_str.to_s.split(' ', 2).first.to_s
end

def parse_scans(path)
  doc = REXML::Document.new(File.read(path, encoding: 'bom|utf-8'))
  scans = []
  doc.elements.each('scans/scan') { |scan| scans << scan }
  scans
end

def text_at(node, xpath)
  node.elements[xpath]&.text.to_s
end

def build_scan_record(scan, bu_map)
  account = text_at(scan, 'account')
  bu = bu_map[account] || { alias: '', code: '-9999' }

  length_node = scan.elements['length']
  width_node = scan.elements['width']
  length = convert_to_inches(length_node&.text.to_s, length_node&.attributes&.[]('unit'))
  width = convert_to_inches(width_node&.text.to_s, width_node&.attributes&.[]('unit'))

  [
    split_date(text_at(scan, 'time')),
    bu[:alias],
    bu[:code],
    format('%.2f', length),
    format('%.2f', width),
    determine_scan_type(length, width),
    text_at(scan, 'filePath'),
    text_at(scan, 'fileName')
  ]
end

def xml_input_paths_from(path)
  return [ path ] if path.file? && path.extname.downcase == '.xml'

  return path.children.select { |child| child.file? && child.extname.downcase == '.xml' }.sort if path.directory?

  []
end

def stage_xml_inputs
  source_dir = xml_source_dir
  return [] unless source_dir.directory?

  FileUtils.mkdir_p(DOWNLOAD_DIR)

  Dir.glob(source_dir.join(XML_FILE_PATTERN).to_s).map do |source|
    source_path = Pathname.new(source)
    target_path = DOWNLOAD_DIR.join(source_path.basename)
    FileUtils.cp(source_path, target_path)
    target_path
  end
end

def default_input_paths
  env_paths = ENV['OVERSIZED_XML_INPUTS'].to_s.split(File::PATH_SEPARATOR).reject(&:empty?)
  return env_paths.flat_map { |path| xml_input_paths_from(Pathname.new(path).expand_path(ROOT)) }.uniq.sort unless env_paths.empty?

  xml_inputs = Array(XML_CFG[:inputs]).flat_map { |path| xml_input_paths_from(Pathname.new(path.to_s).expand_path(ROOT)) }
  return xml_inputs unless xml_inputs.empty?

  staged_inputs = stage_xml_inputs
  return staged_inputs unless staged_inputs.empty?

  location = configured_location
  return [] if location.nil?

  xml_input_paths_from(location) + xml_input_paths_from(location.dirname)
end

def input_paths
  args = ARGV.map(&:to_s).reject(&:empty?)
  return default_input_paths if args.empty? || args == [ 'ALL' ]

  args.flat_map do |arg|
    path = Pathname.new(arg).expand_path(ROOT)
    matches = Dir.glob(path.to_s).map { |match| Pathname.new(match) }
    matches.empty? ? xml_input_paths_from(path) : matches.flat_map { |match| xml_input_paths_from(match) }
  end.uniq.sort
end

def scan_rows(paths, bu_map)
  paths.flat_map { |path| parse_scans(path) }
       .reject { |scan| text_at(scan, 'scanType') == 'Prescan' || text_at(scan, 'client') == 'WScalibrate.exe' }
       .map { |scan| build_scan_record(scan, bu_map) }
end

def write_csv(path, rows)
  FileUtils.mkdir_p(path.dirname)

  CSV.open(path, 'w') do |out|
    out << OUTPUT_HEADER
    rows.each { |row| out << row }
  end
end

def cleanup_download_xml_files(paths)
  paths.each do |path|
    next unless path.dirname == DOWNLOAD_DIR
    next unless File.fnmatch?(XML_FILE_PATTERN, path.basename.to_s)

    FileUtils.rm_f(path)
  end
end

bu_file = business_units_path
raise "missing BU file: #{bu_file}" unless bu_file.file?

inputs = input_paths
raise 'no XML input files found' if inputs.empty?

rows = scan_rows(inputs, load_business_units(bu_file))
write_csv(OUTPUT_PATH, rows)
cleanup_download_xml_files(inputs)

puts "[OK] #{inputs.map(&:basename).join(', ')} -> #{OUTPUT_PATH}"
