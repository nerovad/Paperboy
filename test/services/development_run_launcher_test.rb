# frozen_string_literal: true

require 'test_helper'

class DevelopmentRunLauncherTest < ActiveSupport::TestCase
  test 'enqueue runs the job in this process' do
    enqueued = nil

    Development::RunLauncher::ADAPTER.stub(:enqueue, ->(job) { enqueued = job }) do
      Development::RunLauncher.enqueue(41)
    end

    assert_instance_of Development::RunScriptJob, enqueued
    assert_equal [41], enqueued.arguments
  end

  test 'perform_later outside the test env does not use the shared queue adapter' do
    enqueued = nil

    Rails.stub(:env, ActiveSupport::StringInquirer.new('development')) do
      Development::RunLauncher::ADAPTER.stub(:enqueue, ->(job) { enqueued = job }) do
        Development::RunScriptJob.perform_later(41)
      end
    end

    assert_equal [41], enqueued.arguments
  end
end
