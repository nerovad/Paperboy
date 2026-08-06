# frozen_string_literal: true

require 'test_helper'

module Billing
  class ReportWriterTest < ActiveSupport::TestCase
    test 'writes PDF and XLSX artifacts beneath the output root' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        artifact = ReportArtifact.new(
          name: 'Test report', pdf_name: '../test.pdf', pdf_data: 'PDF',
          xlsx_name: 'test.xlsx', xlsx_data: 'XLSX'
        )

        ReportWriter.new([artifact], root: root).call

        assert_equal 'PDF', root.join('test.pdf').read
        assert_equal 'XLSX', root.join('test.xlsx').read
      end
    end
  end
end
