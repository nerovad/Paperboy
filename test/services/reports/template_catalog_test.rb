# frozen_string_literal: true

require 'test_helper'

module Reports
  class TemplateCatalogTest < ActiveSupport::TestCase
    test 'resolves a template by basename under the report group' do
      root = Pathname(Dir.mktmpdir)
      template = root.join('billing/report.pdf')
      template.dirname.mkpath
      template.write('%PDF-1.4')

      assert_equal template, TemplateCatalog.new(root: root).find(
        group: 'billing', filename: 'report.pdf'
      )
    ensure
      FileUtils.remove_entry(root) if root&.directory?
    end

    test 'rejects paths instead of resolving them' do
      error = assert_raises(TemplateCatalog::InvalidFilename) do
        TemplateCatalog.new.find(group: 'billing', filename: '../secret.pdf')
      end

      assert_equal 'Report template filename must be a basename', error.message
    end
  end
end
