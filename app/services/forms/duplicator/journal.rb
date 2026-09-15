# frozen_string_literal: true

# app/services/forms/duplicator/journal.rb

module Forms
  class Duplicator
    # Every file a duplication writes goes through here, so a failure halfway
    # through -- a migration that will not run, a row that will not save --
    # can put the working tree back exactly as it was.
    class Journal
      attr_reader :created, :updated

      def initialize(root = Rails.root)
        @root = Pathname(root)
        @created = []
        @updated = {}
      end

      def create_file(relative, content)
        path = @root.join(relative)
        raise Error, "#{relative} already exists" if path.exist?

        FileUtils.mkdir_p(path.dirname)
        path.write(content)
        @created << relative
      end

      def update_file(relative, content)
        path = @root.join(relative)
        @updated[relative] ||= path.read
        path.write(content)
      end

      def rollback!
        @created.reverse_each { |relative| FileUtils.rm_f(@root.join(relative)) }
        remove_empty_dirs
        @updated.each { |relative, original| @root.join(relative).write(original) }
      end

      private

      # A copied view folder is only ever created by the copy, so once its
      # files are gone the folder goes too.
      def remove_empty_dirs
        @created.map { |relative| @root.join(relative).dirname }.uniq.each do |dir|
          dir.rmdir if dir.directory? && dir.empty? && dir != @root
        rescue SystemCallError
          next
        end
      end
    end
  end
end
