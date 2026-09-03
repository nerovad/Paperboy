# frozen_string_literal: true

require 'test_helper'

class DslCatalogTest < ActiveSupport::TestCase
  test 'loads every repository DSL into grouped and ungrouped collections' do
    expected_count = Rails.root.glob('config/data_runner/dsl/*.rb').size

    assert_equal expected_count, DslCatalog.entries.size
    assert_equal expected_count, DslCatalog.grouped.values.flatten.size + DslCatalog.ungrouped.size
    assert_includes DslCatalog.grouped.keys, 'chart_of_accounts'
  end

  test 'includes Print 2 Mail groups in the Data Runner control center' do
    assert_includes DslCatalog.grouped.keys, 'print_2_mail'
    assert_includes DslCatalog.grouped.keys, 'print_2_mail_billing_data'
  end

  test 'only resolves known slugs' do
    assert_equal 'employees', DslCatalog.find!('employees').slug
    assert_raises(ActiveRecord::RecordNotFound) { DslCatalog.find!('../Gemfile') }
  end

  test 'exposes workflow enabled state' do
    assert_predicate DslCatalog.find!('revenue_sources'), :enabled?
    assert_not_predicate DslCatalog.find!('parking_lots'), :enabled?
  end

  test 'orchestrated children are disabled for direct manual execution' do
    %w[companions dailypresorts moveresults].each do |slug|
      config = DslCatalog.find!(slug).config

      assert_not Workflow.wants_step?(config, :inject)
      assert Workflow.wants_scheduled_step?(config, :inject, :daily)
    end
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

  test 'shares group refresh instructions across Chart of Accounts DSLs' do
    entries = DslCatalog.grouped.fetch('chart_of_accounts')

    assert_not_empty entries
    entries.each do |entry|
      assert_equal :chart_of_accounts, entry.config.dig(:sop, :shared)
      assert_equal DslSharedSop.fetch!(:chart_of_accounts).fetch(:instructions), entry.sop.fetch(:instructions)
      assert_equal 'chart_of_accounts', entry.sop_reference_group
      assert_equal WorkflowPaths::OUTPUT_ROOT.join(WorkflowPaths::DOWNLOAD_DIR_NAME, entry.output_name),
                   entry.sop_reference_path
    end
  end

  test 'shares group refresh instructions across Print 2 Mail DSLs' do
    entries = DslCatalog.grouped.fetch('print_2_mail')

    assert_not_empty entries
    entries.each do |entry|
      assert_equal :print_2_mail, entry.config.dig(:sop, :shared)
      assert_equal DslSharedSop.fetch!(:print_2_mail).fetch(:instructions), entry.sop.fetch(:instructions)
      assert_equal 'print_2_mail', entry.sop_reference_group
      assert_equal entry.config.dig(:source, :location), entry.sop_reference_path
    end
  end

  test 'uses the shared Print 2 Mail billing SOP' do
    entry = DslCatalog.find!('oms')

    assert_equal :p2m_billing, entry.config.dig(:sop, :shared)
    assert_equal DslSharedSop.fetch!(:p2m_billing).fetch(:instructions), entry.sop.fetch(:instructions)
    assert_equal 'Mail.dat sent to USPS', entry.sop.fetch(:reference_title)
    assert_equal :downloaded_file, entry.sop.fetch(:reference_path)
    expected = Pathname.new('/mnt/o/Outputs/DataRunner').join(ENV.fetch('P2M_STAGING'))
    assert_equal expected, entry.sop_reference_path
  end
end
