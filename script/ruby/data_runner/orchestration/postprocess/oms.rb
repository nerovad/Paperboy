#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'

require_relative '../../constants/workflow_paths'

OUTPUT_FILES = %w[
  companions.csv
  dailypresorts.csv
  moveresults.csv
].freeze
OMS_NUMBER_PATTERN = '\d{8,9}'
MARKER_PATTERN = /\AMail\.dat_(#{OMS_NUMBER_PATTERN})\.zip\z/i

def paths
  usage = "usage: #{$PROGRAM_NAME} ROOT_PATH SENT_PATH OUTPUT_PATH PROCESSED_PATH"
  raise usage unless ARGV.length == 4

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

root_dir, sent_dir, output_dir, processed_dir = paths
marker, oms_number = marker_and_oms_number(sent_dir)
archive_dir = processed_dir.join(oms_number)
FileUtils.mkdir_p(archive_dir)

sources = root_dir.children.select do |path|
  path.file? && path.basename.to_s.include?(oms_number)
end
(sources + [marker]).uniq.each { |path| archive_file(path, archive_dir) }

OUTPUT_FILES.each { |name| remove_file(output_dir.join(name)) }

download_dir = Pathname.new(WorkflowPaths::DOWNLOAD_DIR)
OUTPUT_FILES.each { |name| remove_file(download_dir.join(name)) }
