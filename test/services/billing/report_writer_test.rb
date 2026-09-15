# frozen_string_literal: true

require 'test_helper'

module Billing
  class ReportWriterTest < ActiveSupport::TestCase
    test 'writes both PDFs and XLSX artifacts beneath the output root' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        artifact = ReportArtifact.new(
          name: 'Test report', pdf_name: '../test.pdf', pdf_data: 'PDF',
          overlay_pdf_name: '../poverlay.pdf', overlay_pdf_data: 'OVERLAY PDF',
          xlsx_name: 'test.xlsx', xlsx_data: 'XLSX'
        )

        ReportWriter.new([artifact], root: root).call

        assert_equal 'PDF', root.join('test.pdf').read
        assert_equal 'OVERLAY PDF', root.join('poverlay.pdf').read
        assert_equal 'XLSX', root.join('test.xlsx').read
      end
    end

    test 'replaces reports for enabled billing types only' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        root.join('GDS0726-TC60-Old-v01.pdf').write('old PDF')
        root.join('GDS0726-TC60-Old-v01.xlsx').write('old XLSX')
        root.join('MTP0726-TC60-Keep-v01.pdf').write('keep PDF')
        artifact = ReportArtifact.new(
          name: 'GDS report', pdf_name: 'GDS0726-TC60-New-v02.pdf', pdf_data: 'new PDF',
          xlsx_name: 'GDS0726-TC60-New-v02.xlsx', xlsx_data: 'new XLSX'
        )

        ReportWriter.new([artifact], root: root, replace_types: ['GDS']).call

        assert_not root.join('GDS0726-TC60-Old-v01.pdf').exist?
        assert_not root.join('GDS0726-TC60-Old-v01.xlsx').exist?
        assert root.join('MTP0726-TC60-Keep-v01.pdf').exist?
        assert_equal 'new PDF', root.join('GDS0726-TC60-New-v02.pdf').read
        assert_equal 'new XLSX', root.join('GDS0726-TC60-New-v02.xlsx').read
      end
    end
  end
end
