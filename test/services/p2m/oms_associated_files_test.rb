# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../../app/services/p2m/oms_associated_files'

class P2mOmsAssociatedFilesTest < Minitest::Test
  def test_finds_only_files_for_the_requested_oms_number
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('job')
      directory.mkpath
      expected = %w[
        50000001-companion.csv
        50000001-mail-piece.pdf
        Mail.dat_50000001.zip
        MoveResults_50000001.txt
        Tray_Labels_50000001.pdf
      ]
      excluded = ['50000002-companion.csv', 'Tray_Labels_50000002.pdf', 'unrelated.pdf']
      (expected + excluded).each { |name| directory.join(name).write('fixture') }

      files = P2m::OmsAssociatedFiles.new(root: root).call(directory: 'job', oms_number: '50000001')

      assert_equal expected, files
    end
  end

  def test_finds_the_tray_labels_pdf
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('job')
      directory.mkpath
      directory.join('50000001-mail-piece.pdf').write('mail piece')
      tray_labels = directory.join('Tray_Labels_50000001.pdf')
      tray_labels.write('tray labels')

      file = P2m::OmsAssociatedFiles.new(root: root).tray_labels(
        directory: 'job', oms_number: '50000001'
      )

      assert_equal tray_labels, file
    end
  end

  def test_raises_when_tray_labels_pdf_is_missing
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('job')
      directory.mkpath

      error = assert_raises(ArgumentError) do
        P2m::OmsAssociatedFiles.new(root: root).tray_labels(
          directory: 'job', oms_number: '50000001'
        )
      end

      assert_equal 'Tray Labels PDF not found', error.message
    end
  end

  def test_returns_an_associated_file_for_preview
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('job')
      directory.mkpath
      expected = directory.join('MoveResults_50000001.txt')
      expected.write('results')

      file = P2m::OmsAssociatedFiles.new(root: root).preview(
        directory: 'job', oms_number: '50000001', filename: expected.basename.to_s
      )

      assert_equal expected, file
    end
  end

  def test_rejects_zip_file_previews
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('job')
      directory.mkpath
      directory.join('Mail.dat_50000001.zip').write('archive')

      error = assert_raises(ArgumentError) do
        P2m::OmsAssociatedFiles.new(root: root).preview(
          directory: 'job', oms_number: '50000001', filename: 'Mail.dat_50000001.zip'
        )
      end

      assert_equal 'ZIP files cannot be previewed', error.message
    end
  end

  def test_rejects_files_that_are_not_associated_with_the_oms_number
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('job')
      directory.mkpath
      directory.join('50000002-companion.csv').write('other OMS')

      error = assert_raises(ArgumentError) do
        P2m::OmsAssociatedFiles.new(root: root).preview(
          directory: 'job', oms_number: '50000001', filename: '50000002-companion.csv'
        )
      end

      assert_equal 'associated file not found', error.message
    end
  end
end
