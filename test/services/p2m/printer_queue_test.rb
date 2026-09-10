# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../../app/services/p2m/paths'
require_relative '../../../app/services/p2m/oms_associated_files'
require_relative '../../../app/services/p2m/printer_queue'

module P2m
  class PrinterQueueTest < Minitest::Test
    def test_rejects_selected_non_pdf_files
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory).join('Outputs')
        source = root.join('job').tap(&:mkpath)
        destination = Pathname.new(directory).join('99_Printers')
        source.join('Mail.dat_50000001.zip').write('maildat')
        source.join('50000001-companion.csv').write('companion')

        error = assert_raises(ArgumentError) do
          PrinterQueue.new(root: root, destination: destination).copy(
            directory: 'job', oms_number: '50000001', printer: 'Printer One', queue: 'Queue A',
            filenames: ['50000001-companion.csv']
          )
        end

        assert_match 'only PDF files may be sent to a printer', error.message
      end
    end

    def test_copies_only_pdf_documents_when_filenames_are_omitted
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory).join('Outputs')
        source = root.join('job').tap(&:mkpath)
        destination = Pathname.new(directory).join('99_Printers')
        source.join('Mail.dat_50000001.zip').write('maildat')
        source.join('50000001-companion.csv').write('companion')
        source.join('50000001-document.PDF').write('document')

        count = PrinterQueue.new(root: root, destination: destination).copy(
          directory: 'job', oms_number: '50000001', printer: 'Printer One', queue: 'Queue A'
        )

        assert_equal 1, count
        copied_names = destination.join('Printer One/Queue A').children.map { _1.basename.to_s }
        assert_equal ['50000001-document.PDF'], copied_names
      end
    end

    def test_rejects_destination_path_traversal
      service = PrinterQueue.new(root: '/tmp/source', destination: '/tmp/printers')

      error = assert_raises(ArgumentError) do
        service.copy(directory: 'job', oms_number: '50000001', printer: '../escape', queue: 'Queue A')
      end

      assert_equal 'invalid printer', error.message
    end

    def test_removes_only_selected_files_from_the_printer_queue
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory).join('Outputs')
        source = root.join('job').tap(&:mkpath)
        destination = Pathname.new(directory).join('99_Printers')
        queue = destination.join('Printer One/Queue A').tap(&:mkpath)
        %w[50000001-first.pdf 50000001-second.pdf].each do |name|
          source.join(name).write(name)
          queue.join(name).write(name)
        end

        count = PrinterQueue.new(root: root, destination: destination).remove(
          directory: 'job', oms_number: '50000001', printer: 'Printer One', queue: 'Queue A',
          filenames: ['50000001-first.pdf']
        )

        assert_equal 1, count
        remaining_names = queue.children.map { _1.basename.to_s }
        assert_equal ['50000001-second.pdf'], remaining_names
      end
    end

    def test_removes_only_pdf_documents_when_filenames_are_omitted
      Dir.mktmpdir do |directory|
        root = Pathname.new(directory).join('Outputs')
        source = root.join('job').tap(&:mkpath)
        destination = Pathname.new(directory).join('99_Printers')
        queue = destination.join('Printer One/Queue A').tap(&:mkpath)
        %w[50000001-document.pdf 50000001-companion.csv].each do |name|
          source.join(name).write(name)
          queue.join(name).write(name)
        end

        count = PrinterQueue.new(root: root, destination: destination).remove(
          directory: 'job', oms_number: '50000001', printer: 'Printer One', queue: 'Queue A'
        )

        assert_equal 1, count
        remaining_names = queue.children.map { _1.basename.to_s }
        assert_equal ['50000001-companion.csv'], remaining_names
      end
    end
  end
end
