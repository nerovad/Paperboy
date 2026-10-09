# frozen_string_literal: true

# dsl_map.rb
#
# Canonical file map for ACWEB Excel -> CSV.
#
# Entries are split into per-dataset files under config/data_runner/dsl/<group>.

require_relative '../constants/workflow'

DSL_DIR = File.expand_path('../../../../config/data_runner/dsl', __dir__)

entry_files = Dir[File.join(DSL_DIR, '*', '*.rb')].reject { |path| path.include?('/shared/') }
raise "no DSL files found in #{DSL_DIR}" if entry_files.empty?

entries = entry_files.map do |path|
  entry = TOPLEVEL_BINDING.eval(File.read(path), path)

  raise "invalid DSL entry in #{path}: expected [String, Hash]" unless entry.is_a?(Array) && entry.size == 2 && entry[0].is_a?(String) && entry[1].is_a?(Hash)

  entry
end

keys = entries.map(&:first)
duplicates = keys.group_by(&:itself).select { |_k, v| v.size > 1 }.keys
raise "duplicate DSL keys: #{duplicates.join(', ')}" unless duplicates.empty?

entries.each do |name, config|
  dependency = config[:dependency]
  next if dependency.nil?

  dependencies = dependency.is_a?(Array) ? dependency : [dependency]
  raise "invalid dependency for #{name}: expected a DSL name" unless dependencies.all? { |item| item.is_a?(String) && !item.empty? }

  dependencies.each do |item|
    raise "invalid dependency for #{name}: cannot depend on itself" if item == name
    raise "unknown dependency for #{name}: #{item}" unless keys.include?(item)
  end
end

DSL_MAP = entries.to_h.freeze
