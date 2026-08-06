# frozen_string_literal: true

require 'test_helper'

module Billing
  class EmailReportTest < ActiveSupport::TestCase
    test 'groups PDF and XLSX files by extensionless report name' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        root.join('GDS0727-TC60-Digital-Services-v01.pdf').binwrite('PDF')
        root.join('GDS0727-TC60-Digital-Services-v01.xlsx').binwrite('XLSX')

        report = EmailReport.all(root: root).sole

        assert_equal 'GDS0727-TC60-Digital-Services-v01', report.name
        assert_equal 'GDS', report.billing_type
        assert_equal 2, report.files.length
        assert report.active_by_default?(Set['GDS'])
      end
    end
  end
end
