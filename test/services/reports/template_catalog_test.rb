# frozen_string_literal: true

require 'test_helper'

module Reports
  class TemplateCatalogTest < ActiveSupport::TestCase
    test 'resolves a report template under its family and report directory' do
      root = Pathname(Dir.mktmpdir)
      template = root.join('billing/tc60/tc60.pdf')
      template.dirname.mkpath
      template.write('%PDF-1.4')

      assert_equal template, TemplateCatalog.new(root: root).find(
        family: 'billing', report: 'tc60'
      )
    ensure
      FileUtils.remove_entry(root) if root&.directory?
    end

    test 'rejects paths instead of resolving them' do
      error = assert_raises(TemplateCatalog::InvalidFilename) do
        TemplateCatalog.new.find(family: 'billing', report: '../secret')
      end

      assert_equal 'Report template filename must be a basename', error.message
    end
  end
end
