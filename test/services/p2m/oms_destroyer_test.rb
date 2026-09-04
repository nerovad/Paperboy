# frozen_string_literal: true

require 'test_helper'

module P2m
  class OmsDestroyerTest < ActiveSupport::TestCase
    test 'copies source files and removes OMS files from working locations' do
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory)
        source_root = root.join('source').tap(&:mkpath)
        source = source_root.join('2026/51780767').tap(&:mkpath)
        source.join('51780767-report.pdf').write('pdf')
        source.join('Mail.dat_51780767.zip').write('zip')
        cleanup_paths = %w[shipping staging temporary processed printers].map do |name|
          root.join(name).tap(&:mkpath)
        end
        cleanup_paths[0].join('Mail.dat_51780767.zip').write('zip')
        cleanup_paths[1].join('51780767-report.pdf').write('pdf')
        processed_oms = cleanup_paths[3].join('51780767').tap(&:mkpath)
        processed_oms.join('result.txt').write('result')
        printer_queue = cleanup_paths[4].join('Printer One/Queue A').tap(&:mkpath)
        printer_queue.join('51780767-report.pdf').write('pdf')
        cleanup_paths[2].join('unrelated.pdf').write('keep')

        result = OmsDestroyer.new(
          root: source_root, destination: root.join('destroyed'), cleanup_paths: cleanup_paths
        ).call(directory: '2026/51780767', oms_number: '51780767')

        assert_equal 2, result.fetch(:archived)
        assert_equal 4, result.fetch(:removed)
        assert_equal %w[51780767-report.pdf Mail.dat_51780767.zip],
                     root.join('destroyed/51780767').children.map { |path| path.basename.to_s }.sort
        assert_equal %w[51780767-report.pdf Mail.dat_51780767.zip],
                     source.children.map { |path| path.basename.to_s }.sort
        assert cleanup_paths[2].join('unrelated.pdf').exist?
        refute processed_oms.exist?
        refute printer_queue.exist?
      end
    end

    test 'does not overwrite an existing destroyed OMS' do
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory)
        source = root.join('source/job').tap(&:mkpath)
        source.join('51780767-report.pdf').write('pdf')
        root.join('destroyed/51780767').mkpath
        destroyer = OmsDestroyer.new(
          root: root.join('source'), destination: root.join('destroyed'), cleanup_paths: []
        )

        error = assert_raises(ArgumentError) do
          destroyer.call(directory: 'job', oms_number: '51780767')
        end

        assert_match 'already exists', error.message
        assert source.join('51780767-report.pdf').exist?
      end
    end
  end
end
