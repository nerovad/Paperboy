# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRunTest < ActiveSupport::TestCase
  test 'tracks active and finished states' do
    run = DataRunner::GroupRun.new(status: 'queued')

    assert_predicate run, :active?
    assert_not_predicate run, :finished?

    run.status = 'succeeded'
    assert_not_predicate run, :active?
    assert_predicate run, :finished?
  end
end
