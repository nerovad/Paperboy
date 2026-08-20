# frozen_string_literal: true

require 'test_helper'

class DataRefreshesControllerTest < ActiveSupport::TestCase
  test 'exposes shared refresh actions from each application controller' do
    expected = %w[log progress restart show status update]

    assert_empty expected - Billing::DataRefreshesController.action_methods.to_a
    assert_empty expected - P2m::DataRefreshesController.action_methods.to_a
  end
end
