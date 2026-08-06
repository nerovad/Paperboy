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
  end
end
