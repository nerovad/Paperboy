# frozen_string_literal: true

require 'test_helper'

module Billing
  class ReportFileTest < ActiveSupport::TestCase
    test 'lists only supported report files' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        root.join('report.pdf').write('PDF')
        root.join('report.xlsx').write('XLSX')
        root.join('notes.txt').write('text')

        assert_equal %w[report.pdf report.xlsx].sort,
                     ReportFile.all(root: root).map(&:filename).sort
      end
    end

    test 'rejects traversal outside the report root' do
      assert_raises(ActiveRecord::RecordNotFound) do
        ReportFile.find('../secrets.pdf', root: Pathname(Dir.tmpdir))
      end
    end
  end
end
