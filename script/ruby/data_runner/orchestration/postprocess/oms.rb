#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require_relative '../../../../../lib/paperboy/file_store'

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

  sent_path, output_path, processed_path = ARGV
  [Paperboy::FileStore.for(sent_path), Paperboy::FileStore.for(output_path),
   Paperboy::FileStore.for(processed_path)]
end

def marker_and_oms_number(sent_store)
  target = ENV.fetch('DATARUNNER_QUEUE_OMS', nil)
  marker = sent_store.entries.sort_by { |entry| entry.fetch(:name) }.find do |entry|
    match = entry.fetch(:name).match(MARKER_PATTERN)
    match && (target.nil? || match[1] == target)
  end
  raise "no Mail.dat OMS marker found in #{sent_store.path}" unless marker

  [marker.fetch(:name), marker.fetch(:name).match(MARKER_PATTERN)[1]]
end

def archive_file(source, source_store, destination_store, archive_name)
  source_name = source.fetch(:name)
  downloaded = source_store.download(source_name)
  destination_store.copy(downloaded, archive_name)
  FileUtils.rm_f(downloaded) if downloaded.to_s.start_with?('/tmp/paperboy-smb-file-')
  source_store.remove(source_name)
  puts "[OK] Archived #{source_name} -> #{archive_name}"
end

def remove_file(store, name)
  if store.exist?(name)
    store.remove(name)
    puts "[OK] Removed #{store.path.join(name)}"
  else
    puts "[SKIP] Missing #{store.path.join(name)}"
  end
end

sent_store, output_store, processed_store = paths
_marker, oms_number = marker_and_oms_number(sent_store)
archive_name = oms_number
raise "archive already exists: #{processed_store.path.join(archive_name)}" if processed_store.directory?(archive_name)

sources = sent_store.entries.select do |entry|
  !entry.fetch(:directory) && entry.fetch(:name).include?(oms_number)
end
raise "no staged files found for #{oms_number}" if sources.empty?

processed_store.mkdir(archive_name)
sources.each { |source| archive_file(source, sent_store, processed_store, "#{archive_name}/#{source.fetch(:name)}") }

OUTPUT_FILES.each { |name| remove_file(output_store, name) }
