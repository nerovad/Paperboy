# frozen_string_literal: true

require_relative '../../lib/paperboy/file_store'

class DirectoryListing
  Entry = Data.define(:name, :directory, :size, :modified)
  class Unavailable < StandardError; end

  def initialize(path)
    @path = Pathname.new(path)
  end

  def call
    return shortcut_call if shortcut_reference
    return [entry_for(@path)] if @path.file?
    raise Unavailable, 'The reference is currently unavailable.' unless @path.directory?

    @path.children
         .filter_map { |child| entry_for(child) }
         .sort_by { |entry| [entry.directory ? 0 : 1, entry.name.downcase] }
  rescue SystemCallError, SmbShortcut::CommandError, Paperboy::FileStore::Error
    raise Unavailable, 'The reference is currently unavailable.'
  end

  private

  def entry_for(path)
    stat = path.stat
    Entry.new(name: path.basename.to_s, directory: stat.directory?,
              size: stat.file? ? stat.size : nil, modified: stat.mtime)
  rescue Errno::ENOENT
    nil
  end

  def shortcut_call
    root, relative = shortcut_reference
    store = Paperboy::FileStore.for(root)
    return remote_entries(store.entries) if relative.empty?

    reference = Pathname.new(relative)
    parent = reference.parent.to_s == '.' ? nil : reference.parent.to_s
    remote_entry = store.entries(parent).find { |entry| entry.fetch(:name) == reference.basename.to_s }
    raise Unavailable, 'The reference is currently unavailable.' unless remote_entry

    entries = remote_entry.fetch(:directory) ? store.entries(relative) : [remote_entry]
    remote_entries(entries)
  end

  def shortcut_reference
    match = @path.to_s.match(%r{\A(.+?\.lnk)(?:/(.*))?\z}i)
    return unless match && Pathname.new(match[1]).file?

    [Pathname.new(match[1]), match[2].to_s]
  end

  def remote_entries(entries)
    converted = entries.filter_map do |entry|
      Entry.new(name: entry.fetch(:name), directory: entry.fetch(:directory),
                size: entry[:directory] ? nil : entry[:size], modified: entry[:modified_at])
    end
    converted.sort_by { |entry| [entry.directory ? 0 : 1, entry.name.downcase] }
  end
end
