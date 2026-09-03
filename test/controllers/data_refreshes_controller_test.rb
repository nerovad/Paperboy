# frozen_string_literal: true

require 'test_helper'

class DataRefreshesControllerTest < ActiveSupport::TestCase
  test 'exposes shared refresh actions from each application controller' do
    expected = %w[log progress restart show status update]

    assert_empty expected - Billing::DataRefreshesController.action_methods.to_a
    assert_empty expected - P2m::DataRefreshesController.action_methods.to_a
  end

  test 'loads the active billing period before building refresh groups' do
    callbacks = Billing::DataRefreshesController._process_action_callbacks
    filters = callbacks.select { |callback| callback.kind == :before }.map(&:filter)

    assert_operator filters.index(:set_active_billing_period), :<, filters.index(:load_data_refresh_groups)
  end

  test 'exposes Print 2 Mail stage data actions' do
    assert_includes P2m::StageDataController.action_methods, 'show'
    assert_includes P2m::StageDataController.action_methods, 'create'
    assert_includes P2m::StageDataController.action_methods, 'print_tray_labels'
    assert_includes P2m::OmsUploadsController.action_methods, 'index'
    assert_includes P2m::PreProductionsController.action_methods, 'show'
  end
end
