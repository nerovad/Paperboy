# frozen_string_literal: true

require 'test_helper'

module Billing
  class DataRefreshTest < ActiveSupport::TestCase
    test 'refreshes only groups selected with one' do
      result = TaskRunner::Result.new(id: '00000000-0000-0000-0000-000000000000', success: true)
      calls = []
      runner = lambda do |task:, selector:|
        calls << [task, selector]
        result
      end
      enabled = Struct.new(:slug) do
        def enabled? = true
      end
      disabled = Struct.new(:slug) do
        def enabled? = false
      end
      catalog = {
        'billing' => [enabled.new('oneil'), disabled.new('digital_services')],
        'mail_center_and_warehousing' => [enabled.new('usps')]
      }

      DslCatalog.stub(:grouped, catalog) do
        TaskRunner.stub(:run!, runner) do
          returned = DataRefresh.run!(
            'billing' => '1', 'mail_center_and_warehousing' => '0'
          )

          assert_equal result, returned
        end
      end
      assert_equal [['refresh', ['oneil']]], calls
    end

    test 'defaults billing on and mail center and warehousing off' do
      defaults = DataRefresh::GROUPS.transform_values { |configuration| configuration.fetch(:default) }

      assert_equal true, defaults.fetch('billing')
      assert_equal false, defaults.fetch('mail_center_and_warehousing')
    end

    test 'lists enabled DSL file dates and marks files after the period current' do
      entry = Struct.new(:key, :config) do
        def enabled? = true
      end.new('ONeil', { source: { location: '/data/oneil.csv' } })
      disabled = Struct.new(:key, :config) do
        def enabled? = false
      end.new('Disabled', { source: { location: '/data/disabled.csv' } })
      catalog = {
        'billing' => [entry, disabled],
        'mail_center_and_warehousing' => []
      }
      modified_at = Time.zone.local(2026, 8, 3, 8)

      DslCatalog.stub(:grouped, catalog) do
        File.stub(:mtime, modified_at) do
          group = DataRefresh.groups(end_date: Date.new(2026, 8, 1)).first

          assert_equal 1, group.enabled_dsl_count
          assert_equal ['ONeil'], group.enabled_dsls.map(&:name)
          assert_equal '/data/oneil.csv', group.enabled_dsls.first.location
          assert_equal modified_at, group.enabled_dsls.first.file_date
          assert_predicate group.enabled_dsls.first, :current
          assert_not group.enabled_dsls.first.script
        end
      end
    end

    test 'marks unavailable source files stale' do
      entry = Struct.new(:key, :config) do
        def enabled? = true
      end.new('ONeil', { source: { location: '/missing/oneil.csv' } })
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
      entry = Struct.new(:key, :config) do
        def enabled? = true
      end.new(
        'Warehousing',
        { source: { strategy: :script, script: { path: 'script/download/warehousing.rb' } } }
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
