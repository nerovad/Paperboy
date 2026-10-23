# frozen_string_literal: true

require 'test_helper'

class HumanResourcesRefreshNavigationTest < ActiveSupport::TestCase
  class View
    def initialize(granted)
      @granted = granted
    end

    def paperboy_apps
      [{ key: 'human_resources', label: 'Human Resources', path: '/human_resources' }]
    end

    def can_use_app_feature?(app_key, feature_key)
      @granted && app_key == 'human_resources' && feature_key == 'data_refresh'
    end
  end

  test 'Refresh Data is offered only with the feature grant' do
    denied = NavigationCatalog.new(View.new(false))
    granted = NavigationCatalog.new(View.new(true))

    assert_equal ['Human Resources'], denied.destinations.map(&:label)
    assert_equal ['Human Resources', 'Refresh Data'], granted.destinations.map(&:label)
    assert_equal human_resources_data_refresh_path, granted.destinations.last.path
  end
end
