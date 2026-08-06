# frozen_string_literal: true

require 'test_helper'

module Billing
  class ReportBundleTest < ActiveSupport::TestCase
    test 'packages each PDF and XLSX report' do
      artifact = ReportArtifact.new(
        name: 'Test report', pdf_name: 'test.pdf', pdf_data: 'PDF',
        xlsx_name: 'test.xlsx', xlsx_data: 'XLSX'
      )

      archive = ReportBundle.new([artifact]).call

      Zip::File.open_buffer(archive) do |zip|
        assert_equal %w[test.pdf test.xlsx], zip.entries.map(&:name)
        assert_equal 'PDF', zip.read('test.pdf')
        assert_equal 'XLSX', zip.read('test.xlsx')
      end
    end
  end
end
