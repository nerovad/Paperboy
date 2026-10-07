# frozen_string_literal: true

require 'test_helper'

module Itp
  class RoutesTest < ActionDispatch::IntegrationTest
    test 'support is routed under the itp namespace' do
      assert_routing({ path: '/itp/support', method: :get },
                     { controller: 'itp/support', action: 'index' })
      assert_equal '/itp/support', itp_support_path
    end

    test 'itp root and dashboard routes stay intact' do
      assert_routing({ path: '/itp', method: :get },
                     { controller: 'itp/dashboard', action: 'home' })
      assert_routing({ path: '/itp/dashboard', method: :get },
                     { controller: 'itp/dashboard', action: 'index' })
    end
  end
end
