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

def root_path
  raise "usage: #{$PROGRAM_NAME} ROOT_PATH" unless ARGV.length == 1

  Pathname.new(ARGV.fetch(0)).expand_path
end

def remove_file(path)
  if path.file?
    FileUtils.rm_f(path)
    puts "[OK] Removed #{path}"
  else
    puts "[SKIP] Missing #{path}"
  end
end

output_dir = root_path.join('Output')
OUTPUT_FILES.each { |name| remove_file(output_dir.join(name)) }

download_dir = Pathname.new(WorkflowPaths::DOWNLOAD_DIR)
OUTPUT_FILES.each { |name| remove_file(download_dir.join(name)) }
