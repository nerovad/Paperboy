# frozen_string_literal: true

module Dam
  module ResourceSpace
    # Where ResourceSpace put each resource's files, read off the filestore
    # rather than recomputed.
    #
    # It scrambles a resource into a folder path from a key in its config, so
    # the path cannot be derived from the ref alone. But every file in there is
    # named for the resource it belongs to — 811_<hash>.jpg beside
    # 811scr_<hash>.jpg — so one walk of the tree builds the whole map, and the
    # scramble key is never needed.
    class FilestoreIndex
      # <ref><code>_<hash>.<ext>, where a missing code means the original.
      FILE_NAME = /\A(?<ref>\d+)(?<code>[a-z]*)_(?<hash>[0-9a-z]+)\.(?<extension>[A-Za-z0-9]+)\z/

      Entry = Struct.new(:original, :previews, keyword_init: true) do
        # Biggest first: a screen-sized copy is a better proxy than a tile.
        def proxy = previews.values_at('hpr', 'scr', 'lpr', 'pre', 'col').compact.first

        def thumbnail = previews.values_at('thm', 'col', 'pre').compact.first
      end

      def initialize(root)
        @root = Pathname(root)
      end

      # { ref => Entry }. One pass over the tree; the caller holds it for the
      # length of an import, since walking 94,000 files per resource is not a
      # thing anybody can wait for.
      def build
        index = Hash.new { |hash, ref| hash[ref] = Entry.new(original: nil, previews: {}) }
        walk(@root) do |path|
          match = FILE_NAME.match(path.basename.to_s)
          next unless match

          entry = index[match[:ref].to_i]
          if match[:code].empty?
            entry.original = path
          else
            entry.previews[match[:code]] ||= path
          end
        end
        index
      end

      private

      def walk(directory, &block)
        directory.children.sort.each do |child|
          if child.directory?
            walk(child, &block)
          elsif child.file? && child.size.positive?
            block.call(child)
          end
        end
      rescue Errno::EACCES, Errno::ENOENT
        # A share with a folder we cannot read is still worth indexing.
        nil
      end
    end
  end
end
