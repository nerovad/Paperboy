# frozen_string_literal: true

class DslGroupUpdater
  class DslNameConflict < StandardError; end

  GROUP_PATTERN = /^    group: \{\n      name: ['"][^'"]+['"]\n    \},\n/
  GROUP_NAME_PATTERN = /\A[a-z0-9_]+\z/

  def initialize(group:, slugs:)
    @group = group.to_s
    @slugs = Array(slugs).map(&:to_s)
  end

  def update!
    raise ActiveRecord::RecordNotFound, "Invalid DSL group" unless @group.match?(GROUP_NAME_PATTERN)

    wanted = DslCatalog.entries.select { |entry| @slugs.include?(entry.slug) }.to_h { |entry| [ entry.slug, entry ] }
    raise ActiveRecord::RecordNotFound, "Unknown DSL in group update" if wanted.size != @slugs.uniq.size

    DslCatalog.entries.each do |entry|
      next unless entry.group == @group || wanted.key?(entry.slug)

      write_group(entry, wanted.key?(entry.slug) ? @group : nil)
    end
    DslCatalog.reload!
  end

  def rename!(new_group)
    normalized = new_group.to_s.parameterize(separator: "_")
    raise ActiveRecord::RecordNotFound, "Invalid DSL group" unless normalized.match?(GROUP_NAME_PATTERN)

    conflicting_name = dsl_name(normalized)
    raise DslNameConflict, conflicting_name if conflicting_name

    matching_entries.each { |entry| write_group(entry, normalized) }
    DslCatalog.reload!
    normalized
  end

  def delete!
    matching_entries.each { |entry| write_group(entry, nil) }
    DslCatalog.reload!
  end

  private

  def matching_entries
    entries = DslCatalog.entries.select { |entry| entry.group == @group }
    raise ActiveRecord::RecordNotFound, "Unknown DSL group" if entries.empty?

    entries
  end

  def dsl_name(group)
    DslCatalog.entries.find do |entry|
      group == entry.slug || group == entry.key.to_s.parameterize(separator: "_")
    end&.key
  end

  def write_group(entry, group)
    source = entry.path.read
    without_group = source.sub(GROUP_PATTERN, "")
    updated = group ? insert_group(without_group, group) : without_group
    entry.path.write(updated) unless updated == source
  end

  def insert_group(source, group)
    group_block = "    group: {\n      name: '#{group}'\n    },\n"
    source.sub(/^    source: \{\n/, "#{group_block}    source: {\n")
  end
end
