#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'

OUTPUT_FILES = %w[
  companions.csv
  dailypresorts.csv
  moveresults.csv
].freeze
OMS_NUMBER_PATTERN = '\d{8,9}'
MARKER_PATTERN = /\AMail\.dat_(#{OMS_NUMBER_PATTERN})\.zip\z/i

def paths
  usage = "usage: #{$PROGRAM_NAME} SENT_PATH OUTPUT_PATH PROCESSED_PATH"
  raise usage unless ARGV.length == 3

  ARGV.map { |value| Pathname.new(value).expand_path }
end

def marker_and_oms_number(sent_dir)
  marker = sent_dir.children.select(&:file?).sort.find { |path| path.basename.to_s.match?(MARKER_PATTERN) }
  raise "no Mail.dat OMS marker found in #{sent_dir}" unless marker

  [marker, marker.basename.to_s.match(MARKER_PATTERN)[1]]
end

def archive_file(source, archive_dir)
  target = archive_dir.join(source.basename)
  FileUtils.rm_f(target)
  FileUtils.mv(source, target)
  puts "[OK] Archived #{source} -> #{target}"
end

def remove_file(path)
  if path.file?
    FileUtils.rm_f(path)
    puts "[OK] Removed #{path}"
  else
    puts "[SKIP] Missing #{path}"
  end
end

sent_dir, output_dir, processed_dir = paths
_marker, oms_number = marker_and_oms_number(sent_dir)
archive_dir = processed_dir.join(oms_number)
raise "archive already exists: #{archive_dir}" if archive_dir.exist?

sources = sent_dir.children.select { |path| path.file? && path.basename.to_s.include?(oms_number) }
raise "no staged files found for #{oms_number}" if sources.empty?

FileUtils.mkdir_p(archive_dir)
sources.each { |path| archive_file(path, archive_dir) }

OUTPUT_FILES.each { |name| remove_file(output_dir.join(name)) }
