# frozen_string_literal: true

require 'test_helper'

module Billing
  class DataRefreshTest < ActiveSupport::TestCase
    test 'refreshes only groups selected with one' do
      result = DataRunner::GroupRun.new(group_name: DataRefresh::GROUP_RUN_NAME, total_count: 1)
      calls = []
      runner = lambda do |**arguments|
        calls << arguments
        result
      end
      enabled = Struct.new(:slug, :key) do
        def enabled? = true
      end
      disabled = Struct.new(:slug, :key) do
        def enabled? = false
      end
      catalog = {
        'billing' => [enabled.new('oneil', 'ONeil'), disabled.new('digital_services', 'DigitalServices')],
        'mail_center_and_warehousing' => [enabled.new('usps', 'USPS')]
      }

      DslCatalog.stub(:grouped, catalog) do
        DataRunner::GroupRefresh.stub(:start!, runner) do
          DataRefresh.run!(
            { 'billing' => '1', 'mail_center_and_warehousing' => '0' }, requested_by: 'employee@example.com'
          )
        end
      end
      assert_equal DataRefresh::GROUP_RUN_NAME, calls.first.fetch(:group)
      assert_equal ['oneil'], calls.first.fetch(:entries).map(&:slug)
      assert_equal 'employee@example.com', calls.first.fetch(:requested_by)
    end

    test 'defaults billing on and mail center and warehousing off' do
      defaults = DataRefresh::GROUPS.transform_values { |configuration| configuration.fetch(:default) }

      assert_equal true, defaults.fetch('billing')
      assert_equal false, defaults.fetch('mail_center_and_warehousing')
    end

    test 'resolves an SOP reference from the displayed source location' do
      dsl = DataRefresh::Dsl.new(
        name: 'ONeil', slug: 'oneil', location: '/data/oneil.csv', file_date: nil,
        current: false, script: false, sop: { reference_path: :source_location }
      )

      assert_equal '/data/oneil.csv', dsl.sop_reference_path
    end

    test 'lists enabled DSL file dates and marks files after the period current' do
      entry = Struct.new(:key, :slug, :config, :sop) do
        def enabled? = true
      end.new(
        'ONeil', 'oneil', { source: { location: '/data/oneil.csv' } },
        { title: 'How to Download', instructions: ['Export the report.'] }
      )
      disabled = Struct.new(:key, :slug, :config, :sop) do
        def enabled? = false
      end.new('Disabled', 'disabled', { source: { location: '/data/disabled.csv' } }, nil)
      catalog = {
        'billing' => [entry, disabled],
        'mail_center_and_warehousing' => []
      }
      modified_at = Time.zone.local(2026, 8, 2, 8)

      DslCatalog.stub(:grouped, catalog) do
        File.stub(:mtime, modified_at) do
          group = DataRefresh.groups(end_date: Date.new(2026, 8, 1)).first

          assert_equal 1, group.enabled_dsl_count
          assert_equal ['ONeil'], group.enabled_dsls.map(&:name)
          assert_equal 'oneil', group.enabled_dsls.first.slug
          assert_equal '/data/oneil.csv', group.enabled_dsls.first.location
          assert_equal modified_at, group.enabled_dsls.first.file_date
          assert_equal 'How to Download', group.enabled_dsls.first.sop.fetch(:title)
          assert_predicate group.enabled_dsls.first, :current
          assert_not group.enabled_dsls.first.script
        end
      end
    end

    test 'marks unavailable source files stale' do
      entry = Struct.new(:key, :slug, :config, :sop) do
        def enabled? = true
      end.new('ONeil', 'oneil', { source: { location: '/missing/oneil.csv' } }, nil)
      catalog = { 'billing' => [entry], 'mail_center_and_warehousing' => [] }

      DslCatalog.stub(:grouped, catalog) do
        File.stub(:mtime, ->(*) { raise Errno::ENOENT }) do
          dsl = DataRefresh.groups(end_date: Date.new(2026, 8, 1)).first.enabled_dsls.first

          assert_nil dsl.file_date
          assert_not dsl.current
        end
      end
    end

    test 'lists script DSLs with the script name and current date' do
      entry = Struct.new(:key, :slug, :config, :sop) do
        def enabled? = true
      end.new(
        'Warehousing', 'warehousing',
        { source: { strategy: :script, script: { path: 'script/download/warehousing.rb' } } }, nil
      )
      catalog = { 'billing' => [entry], 'mail_center_and_warehousing' => [] }
      today = Date.new(2026, 8, 13)

      DslCatalog.stub(:grouped, catalog) do
        Date.stub(:current, today) do
          dsl = DataRefresh.groups(end_date: Date.new(2026, 8, 1)).first.enabled_dsls.first

          assert_equal 'warehousing.rb', dsl.location
          assert_equal today, dsl.file_date
          assert dsl.script
        end
      end
    end
  end
end
