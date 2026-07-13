# frozen_string_literal: true

# dsl_map.rb
#
# Canonical file map for ACWEB Excel -> CSV.
#
# Entries are split into per-dataset files under ./dsl and loaded here.

require_relative '../constants/workflow'

DSL_DIR = File.join(__dir__, '../..', 'dsl')

entry_files = Dir[File.join(DSL_DIR, '*.rb')]
raise "no DSL files found in #{DSL_DIR}" if entry_files.empty?

entries = entry_files.map do |path|
  entry = TOPLEVEL_BINDING.eval(File.read(path), path)

  raise "invalid DSL entry in #{path}: expected [String, Hash]" unless entry.is_a?(Array) && entry.size == 2 && entry[0].is_a?(String) && entry[1].is_a?(Hash)

  entry
end

keys = entries.map(&:first)
duplicates = keys.group_by(&:itself).select { |_k, v| v.size > 1 }.keys
raise "duplicate DSL keys: #{duplicates.join(', ')}" unless duplicates.empty?

DSL_MAP = entries.to_h.freeze
