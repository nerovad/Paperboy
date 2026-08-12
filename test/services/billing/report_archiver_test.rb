# frozen_string_literal: true

require 'test_helper'

module Billing
  class ReportArchiverTest < ActiveSupport::TestCase
    test 'moves selected report files into the archive location' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory).join('reports').tap(&:mkpath)
        archive_root = Pathname(directory).join('archive').tap(&:mkpath)
        root.join('report.pdf').write('PDF')
        location = ArchiveLocation.new(path: archive_root, root: archive_root)

        count = ReportArchiver.new(
          filenames: ['report.pdf'], destination: location, root: root
        ).call

        assert_equal 1, count
        assert_not root.join('report.pdf').exist?
        assert_equal 'PDF', archive_root.join('report.pdf').read
      end
    end

    test 'does not overwrite an archived report' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory).join('reports').tap(&:mkpath)
        archive_root = Pathname(directory).join('archive').tap(&:mkpath)
        root.join('report.pdf').write('new')
        archive_root.join('report.pdf').write('existing')
        location = ArchiveLocation.new(path: archive_root, root: archive_root)

        assert_raises(ReportArchiver::FileExists) do
          ReportArchiver.new(
            filenames: ['report.pdf'], destination: location, root: root
          ).call
        end
        assert_equal 'existing', archive_root.join('report.pdf').read
        assert root.join('report.pdf').exist?
      end
    end
  end
end
