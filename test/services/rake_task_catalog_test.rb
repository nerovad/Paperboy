# frozen_string_literal: true

require 'test_helper'

class RakeTaskCatalogTest < ActiveSupport::TestCase
  test 'discovers runnable DataRunner namespaced tasks from the Rakefile' do
    assert_includes RakeTaskCatalog.data_runner, 'dsl_stub'
    assert_includes RakeTaskCatalog.data_runner, 'inject'
    assert_includes RakeTaskCatalog.runnable, 'inject'
    assert_not_includes RakeTaskCatalog.runnable, 'dsl_stub'
    assert_empty RakeTaskCatalog.runnable - TaskRunner::TASKS
  end
end
