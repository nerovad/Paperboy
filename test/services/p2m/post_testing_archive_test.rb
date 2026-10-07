# frozen_string_literal: true

require 'test_helper'

module P2m
  module PostTestingArchiveExamples
    def with_job
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory)
        source = root.join('Outputs')
        historical = source.join('July').tap(&:mkpath)
        paths = {
          source: source, historical: historical, processed: root.join('processed'),
          report: root.join('report.json'),
          first: historical.join('51780767-a.pdf'), second: historical.join('51780767-b.pdf'),
          neighbor: historical.join('51780768-notes.pdf')
        }
        paths.fetch(:first).write('pdf-a')
        paths.fetch(:second).write('pdf-b')
        paths.fetch(:neighbor).write('other')
        archive = PostTestingArchive.new(
          report_path: paths.fetch(:report), processed_root: paths.fetch(:processed),
          source_root: source, search: ->(*) { [job_row(paths)] }
        )
        archive.preview
        yield archive, paths
      end
    end

    def job_row(paths)
      {
        'oms_number' => '51780767', 'mail_date' => '2026-07-15', 'status' => 'incomplete',
        'detail' => 'Missing: companion, daily presort, moveresults.',
        'files' => [paths.fetch(:second).to_s, paths.fetch(:first).to_s]
      }
    end
  end

  class PostTestingArchiveTest < ActiveSupport::TestCase
    include PostTestingArchiveExamples

    test 'previews the fixed quarter and leaves historical files in place' do
      captured = nil
      with_job do |_archive, paths|
        listed = PostTestingArchive.new(
          report_path: paths.fetch(:report), processed_root: paths.fetch(:processed),
          source_root: paths.fetch(:source),
          search: lambda { |start_date, end_date|
            captured = [start_date, end_date]
            [job_row(paths)]
          }
        ).preview

        assert_equal [Date.new(2026, 7, 1), Date.new(2026, 9, 30)], captured
        assert_equal(['51780767'], listed.map { |job| job.fetch('oms_number') })
        assert_equal ['51780767-a.pdf', '51780767-b.pdf'], listed.first.fetch('files')
        assert paths.fetch(:first).exist?
        assert paths.fetch(:neighbor).exist?
      end
    end

    test 'moves one OMS into Processed and leaves another OMS in the directory' do
      with_job do |archive, paths|
        result = archive.move('51780767')

        refute result.fetch('error')
        assert_equal 'Moved 2 files for 51780767.', result.fetch('message')
        assert_equal 'pdf-a', paths.fetch(:processed).join('51780767/51780767-a.pdf').read
        refute paths.fetch(:first).exist?
        assert paths.fetch(:neighbor).exist?
        assert_predicate paths.fetch(:historical), :directory?
      end
    end

    test 'removes a historical file when Processed already has the same contents' do
      with_job do |archive, paths|
        destination = paths.fetch(:processed).join('51780767').tap(&:mkpath)
        destination.join('51780767-a.pdf').write('pdf-a')

        result = archive.move('51780767')

        refute result.fetch('error')
        assert_equal ['51780767-a.pdf'], result.fetch('removed')
        assert_equal ['51780767-b.pdf'], result.fetch('moved')
        assert_equal 'pdf-a', destination.join('51780767-a.pdf').read
        refute paths.fetch(:first).exist?
      end
    end

    test 'stops an OMS when Processed has different contents' do
      with_job do |archive, paths|
        destination = paths.fetch(:processed).join('51780767').tap(&:mkpath)
        destination.join('51780767-b.pdf').write('different')

        result = archive.move('51780767')

        assert result.fetch('error')
        assert_equal ['51780767-a.pdf'], result.fetch('moved')
        assert_equal 'different', destination.join('51780767-b.pdf').read
        assert paths.fetch(:second).exist?
        assert_match 'Stopped 51780767 at 51780767-b.pdf', result.fetch('message')
      end
    end

    test 'refuses a file outside the historical tree before moving anything' do
      with_job do |_archive, paths|
        Dir.mktmpdir do |outside|
          outsider = Pathname.new(outside).join('Mail.dat_51780767.zip').tap { |path| path.write('secret') }
          tampered = PostTestingArchive.new(
            report_path: paths.fetch(:report), processed_root: paths.fetch(:processed),
            source_root: paths.fetch(:source),
            search: ->(*) { [job_row(paths).merge('files' => [outsider.to_s, paths.fetch(:first).to_s])] }
          )
          tampered.preview

          error = assert_raises(ArgumentError) { tampered.move('51780767') }

          assert_match 'historical tree', error.message
          assert outsider.exist?
          assert paths.fetch(:first).exist?
          refute paths.fetch(:processed).join('51780767').exist?
        end
      end
    end

    test 'requires the OMS to be in the current search report' do
      with_job do |archive, _paths|
        error = assert_raises(ArgumentError) { archive.move('51780768') }

        assert_match 'Reload Post Testing Archive', error.message
      end
    end
  end
end
