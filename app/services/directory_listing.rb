# frozen_string_literal: true

class DirectoryListing
  Entry = Data.define(:name, :directory, :size, :modified)
  class Unavailable < StandardError; end

  def initialize(path)
    @path = Pathname.new(path)
  end

  def call
    raise Unavailable, 'The folder is currently unavailable.' unless @path.directory?

    @path.children
         .filter_map { |child| entry_for(child) }
         .sort_by { |entry| [entry.directory ? 0 : 1, entry.name.downcase] }
  rescue SystemCallError
    raise Unavailable, 'The folder is currently unavailable.'
  end

  private

  def entry_for(path)
    stat = path.stat
    Entry.new(name: path.basename.to_s, directory: stat.directory?,
              size: stat.file? ? stat.size : nil, modified: stat.mtime)
  rescue Errno::ENOENT
    nil
  end
end
