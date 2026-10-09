# frozen_string_literal: true

require 'test_helper'

class EnvironmentAccessTest < ActiveSupport::TestCase
  test 'the deployed development and staging servers each ask for their own grant' do
    assert_equal 'dev', EnvironmentAccess.key_for(host: 'dev-gsa-forms', rails_env: 'development')
    assert_equal 'stage', EnvironmentAccess.key_for(host: 'stage-gsa-forms', rails_env: 'staging')
  end

  test 'production, the test suite and localhost ask for none' do
    assert_nil EnvironmentAccess.key_for(host: 'gsa-forms', rails_env: 'production')
    assert_nil EnvironmentAccess.key_for(host: 'www.example.com', rails_env: 'test')
    assert_nil EnvironmentAccess.key_for(host: 'localhost', rails_env: 'development')
    assert_nil EnvironmentAccess.key_for(host: '127.0.0.1', rails_env: 'development')
  end

  test 'a refused visitor is sent to the production server' do
    assert_equal 'https://gsa-forms', EnvironmentAccess.production_url
  end

  test 'labels and keys come from one list' do
    assert_equal %w[dev stage], EnvironmentAccess.permission_keys
    assert_equal 'Stage', EnvironmentAccess.label_for('stage')
    assert_nil EnvironmentAccess.label_for('production')
  end
end
