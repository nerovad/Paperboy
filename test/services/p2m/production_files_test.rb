# frozen_string_literal: true

require 'test_helper'

module P2m
  class ProductionFilesTest < ActiveSupport::TestCase
    test 'groups files by printer and queue and skips empty queues' do
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory)
        queue = root.join('Printer One/Queue A').tap(&:mkpath)
        root.join('Printer One/Empty').mkpath
        queue.join('second.pdf').write('second')
        queue.join('first.pdf').write('first')

        result = ProductionFiles.new(root: root).call

        assert_equal 1, result.size
        assert_equal 'Printer One', result.first.fetch('printer')
        assert_equal 'Queue A', result.first.fetch('queue')
        assert_equal %w[first.pdf second.pdf], result.first.fetch('files')
      end
    end

    test 'resolves a file beneath the requested printer queue' do
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory)
        file = root.join('Printer One/Queue A/output.pdf')
        file.dirname.mkpath
        file.write('pdf')

        resolved = ProductionFiles.new(root: root).preview(
          printer: 'Printer One', queue: 'Queue A', filename: 'output.pdf'
        )

        assert_equal file, resolved
      end
    end

    test 'rejects traversal outside the printer root' do
      Dir.mktmpdir do |directory|
        service = ProductionFiles.new(root: directory)

        assert_raises(ArgumentError) do
          service.preview(printer: '..', queue: 'Queue A', filename: 'output.pdf')
        end
      end
    end
  end
end
