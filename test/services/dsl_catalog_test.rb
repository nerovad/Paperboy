# frozen_string_literal: true

require 'test_helper'

class DslCatalogTest < ActiveSupport::TestCase
  test 'loads every repository DSL into grouped and ungrouped collections' do
    expected_count = Rails.root.glob('config/data_runner/dsl/*.rb').size

    assert_equal expected_count, DslCatalog.entries.size
    assert_equal expected_count, DslCatalog.grouped.values.flatten.size + DslCatalog.ungrouped.size
    assert_includes DslCatalog.grouped.keys, 'chart_of_accounts'
  end

  test 'only resolves known slugs' do
    assert_equal 'employees', DslCatalog.find!('employees').slug
    assert_raises(ActiveRecord::RecordNotFound) { DslCatalog.find!('../Gemfile') }
  end

  test 'exposes workflow enabled state' do
    assert_predicate DslCatalog.find!('revenue_sources'), :enabled?
    assert_not_predicate DslCatalog.find!('parking_lots'), :enabled?
  end

  test 'scripted sources have no external location' do
    scripted = DslCatalog.entries.select do |entry|
      entry.config.dig(:source, :strategy) == :script
    end

    assert_not_empty scripted
    scripted.each do |entry|
      assert_nil entry.config.fetch(:source).fetch(:location),
                 "#{entry.slug} scripted source must set location to nil"
    end
  end

  test 'exposes SOPs only for supported groups' do
    assert_equal 'VCPrint', DslCatalog.find!('vcprint').sop.fetch(:source_system)

    entry = DslCatalog::Entry.new(
      key: 'Unsupported', slug: 'unsupported', path: nil,
      config: { group: { name: 'other' }, sop: { instructions: ['Do something.'] } }
    )

    assert_nil entry.sop
  end

  test 'resolves an SOP reference from its source location' do
    entry = DslCatalog.find!('document_automation')

    assert_equal entry.config.dig(:source, :location), entry.sop_reference_path
  end

  test 'resolves an SOP reference from its downloaded file' do
    entry = DslCatalog.find!('agencies')

    assert_equal WorkflowPaths::OUTPUT_ROOT.join(WorkflowPaths::DOWNLOAD_DIR_NAME, 'agencies.xlsx'),
                 entry.sop_reference_path
  end
end
