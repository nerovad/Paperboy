# frozen_string_literal: true

require 'test_helper'

module P2m
  class DataRefreshTest < ActiveSupport::TestCase
    test 'configures the requested Data Runner groups' do
      labels = DataRefresh::GROUPS.transform_values { |configuration| configuration.fetch(:label) }

      assert_equal 'Print 2 Mail', labels.fetch('print_2_mail')
      assert_equal 'Print 2 Mail Billing Data', labels.fetch('print_2_mail_billing_data')
    end

    test 'refreshes enabled DSLs from selected groups' do
      result = DataRunner::GroupRun.new(group_name: DataRefresh::GROUP_RUN_NAME, total_count: 2)
      calls = []
      runner = lambda do |**arguments|
        calls << arguments
        result
      end
      entry = Struct.new(:slug, :key) do
        def enabled? = true
      end
      catalog = {
        'print_2_mail' => [entry.new('p2mjobs', 'P2mjobs')],
        'print_2_mail_billing_data' => [entry.new('oms', 'Oms')]
      }

      DslCatalog.stub(:grouped, catalog) do
        DataRunner::GroupRefresh.stub(:start!, runner) do
          DataRefresh.run!(
            { 'print_2_mail' => '1', 'print_2_mail_billing_data' => '1' },
            requested_by: 'employee@example.com'
          )
        end
      end

      assert_equal DataRefresh::GROUP_RUN_NAME, calls.first.fetch(:group)
      assert_equal %w[p2mjobs oms], calls.first.fetch(:entries).map(&:slug)
    end

    test 'describes an orchestrated DSL by its queue path' do
      entry = Struct.new(:key, :slug, :config, :sop) do
        def enabled? = true
      end.new(
        'Oms', 'oms',
        {
          orchestration: {
            root_path: '/mnt/o/Outputs/DataRunner', sent_path: '00_SentToUSPS',
            queue: { path: :sent_path }
          }
        },
        nil
      )
      catalog = { 'print_2_mail' => [], 'print_2_mail_billing_data' => [entry] }

      DslCatalog.stub(:grouped, catalog) do
        dsl = DataRefresh.groups.last.enabled_dsls.first

        assert_equal '/mnt/o/Outputs/DataRunner/00_SentToUSPS', dsl.location
        assert dsl.script
        assert dsl.current
      end
    end
  end
end
