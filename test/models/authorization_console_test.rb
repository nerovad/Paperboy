# frozen_string_literal: true

require 'test_helper'

# The registry the console picker, the console switcher, the access checks and
# the form builder's routing dropdown all read from.
class AuthorizationConsoleTest < ActiveSupport::TestCase
  test 'every console is registered under a distinct key' do
    keys = AuthorizationConsole::ALL.map(&:key)

    assert_equal keys.uniq, keys
    assert_includes keys, AuthorizationConsole::CIR.key
  end

  test 'every console names a route helper that exists' do
    AuthorizationConsole::ALL.each do |console|
      assert Rails.application.routes.url_helpers.respond_to?(console.route_name),
             "#{console.key} points at #{console.route_name}, which is not a route"
    end
  end

  test 'routing keys stay unique across consoles' do
    keys = AuthorizationConsole.routing_keys

    assert_equal keys.uniq, keys
  end

  test 'the CIR routing key resolves back to the CIR console' do
    assert_equal AuthorizationConsole::CIR, AuthorizationConsole.console_for_routing_key('cir_location')
    assert_equal 'CIR Incident Manager (by location)', AuthorizationConsole.routing_label('cir_location')
  end

  test 'the parking and safety routing keys are untouched by the new console' do
    assert_equal AuthorizationConsole::SERVICES, AuthorizationConsole.console_for_routing_key('P')
    assert_equal AuthorizationConsole::HCA_SAFETY, AuthorizationConsole.console_for_routing_key('hca_safety')
  end

  test 'an unknown routing key resolves to no console and routes to nobody' do
    assert_nil AuthorizationConsole.console_for_routing_key('nonsense')
    assert_empty AuthorizationConsole.approver_ids_for('nonsense', nil)
    assert_nil AuthorizationConsole.inbox_conditions_for('nonsense', ['1'])
  end
end
