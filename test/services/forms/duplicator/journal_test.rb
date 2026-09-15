# frozen_string_literal: true

require 'test_helper'

module Forms
  class Duplicator
    class JournalTest < ActiveSupport::TestCase
      setup do
        @root = Pathname(Dir.mktmpdir('duplicator-journal'))
        @root.join('config').mkpath
        @root.join('config/routes.rb').write("original\n")
      end

      teardown { FileUtils.rm_rf(@root) }

      test 'rollback removes created files and their new folders and restores edited ones' do
        journal = Journal.new(@root)
        journal.create_file('app/views/forms/copies/new.html.erb', 'new')
        journal.update_file('config/routes.rb', "changed\n")
        journal.update_file('config/routes.rb', "changed twice\n")

        journal.rollback!

        assert_not @root.join('app/views/forms/copies').exist?
        assert_equal "original\n", @root.join('config/routes.rb').read
      end

      test 'refuses to overwrite a file that is already there' do
        error = assert_raises(Error) { Journal.new(@root).create_file('config/routes.rb', 'x') }

        assert_includes error.message, 'already exists'
        assert_equal "original\n", @root.join('config/routes.rb').read
      end
    end
  end
end
